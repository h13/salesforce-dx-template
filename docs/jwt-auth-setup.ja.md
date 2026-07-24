# JWT Bearer Flow 認証セットアップ手順

> **English version**: [jwt-auth-setup.md](jwt-auth-setup.md)

CI/CD から Salesforce org にデプロイするための JWT Bearer Flow の設定手順。

## 概要

```
GitHub Actions → JWT で認証 → Salesforce org にデプロイ
```

必要なもの:

- Salesforce org の管理者アクセス
- OpenSSL（鍵生成用）
- GitHub リポジトリの Settings アクセス

## 1. 秘密鍵と証明書の生成

ローカルで実行:

```bash
# 秘密鍵を生成
openssl genrsa -out server.key 2048

# 証明書を生成（有効期限 365 日）
openssl req -new -x509 -key server.key -out server.crt -days 365 \
  -subj "/CN=salesforce-ci/O=YourCompany"
```

`server.key` が CI で使う秘密鍵、`server.crt` が Salesforce に登録する証明書。

## 2. Salesforce で Connected App を作成

### Sandbox org で設定

1. **設定** → クイック検索で「アプリケーションマネージャ」を検索
2. **新規接続アプリケーション** をクリック
3. 以下を入力:
   - 接続アプリケーション名: `CI Deploy`
   - API 参照名: `CI_Deploy`
   - 取引先責任者メール: 管理者のメール
4. **OAuth 設定の有効化** にチェック
5. 設定:
   - コールバック URL: `https://login.salesforce.com/services/oauth2/callback`
   - **デジタル署名を使用** にチェック → `server.crt` をアップロード
   - OAuth スコープ:
     - `Manage user data via APIs (api)`
     - `Manage user data via Web browsers (web)`
     - `Perform requests at any time (refresh_token, offline_access)`
6. **保存**

### アクセスポリシーの設定

1. 作成した Connected App を開く
2. **ポリシーを管理** → **編集**
3. 許可されているユーザー: **管理者が承認したユーザーは事前承認済み**
4. **保存**
5. **プロファイル** セクションで「システム管理者」を追加

### コンシューマーキーを取得

1. Connected App の詳細画面で **コンシューマーの詳細を管理** をクリック
2. **コンシューマーキー** をコピー（これが `SF_CLIENT_ID`）

## 3. Production org でも同じ手順を実行

Production org にも同じ Connected App を作成する。同じ `server.crt` を使えば、同じ秘密鍵で両方の org に認証できる。

## 4. GitHub Secrets の設定

リポジトリの **Settings** → **Environments** で2つの環境を作成:

### `sandbox` 環境

| Secret 名         | 値                                                                       |
| ----------------- | ------------------------------------------------------------------------ |
| `SF_CLIENT_ID`    | Connected App のコンシューマーキー                                       |
| `SF_JWT_KEY`      | `server.key` の中身（PEM テキスト全体）                                  |
| `SF_USERNAME`     | Sandbox の管理者ユーザー名（例: `admin@company.com.sandbox1`）           |
| `SF_INSTANCE_URL` | Sandbox の URL（例: `https://mycompany--dev.sandbox.my.salesforce.com`） |

### `production` 環境

| Secret 名         | 値                                                             |
| ----------------- | -------------------------------------------------------------- |
| `SF_CLIENT_ID`    | Production の Connected App のコンシューマーキー               |
| `SF_JWT_KEY`      | 同じ `server.key` の中身                                       |
| `SF_USERNAME`     | Production の管理者ユーザー名（例: `admin@company.com`）       |
| `SF_INSTANCE_URL` | Production の URL（例: `https://mycompany.my.salesforce.com`） |

### CI validate 用の追加 Secrets（リポジトリレベル）

PR の validate ジョブは環境外で動くため、リポジトリレベルにも Sandbox 用の Secrets が必要:

| Secret 名                 | 値                                            |
| ------------------------- | --------------------------------------------- |
| `SF_CLIENT_ID`            | Sandbox の Connected App のコンシューマーキー |
| `SF_JWT_KEY`              | `server.key` の中身                           |
| `SF_SANDBOX_USERNAME`     | Sandbox の管理者ユーザー名                    |
| `SF_SANDBOX_INSTANCE_URL` | Sandbox の URL                                |

## 5. ローカルでの認証テスト

```bash
sf org login jwt \
  --client-id YOUR_CLIENT_ID \
  --jwt-key-file server.key \
  --username admin@company.com.sandbox1 \
  --instance-url https://mycompany--dev.sandbox.my.salesforce.com \
  --alias sandbox
```

成功すると以下が表示される:

```
Successfully authorized admin@company.com.sandbox1 with org ID 00D...
```

## 6. 動作確認

```bash
# Sandbox にデプロイテスト
sf project deploy start --dry-run --target-org sandbox --wait 30
```

## トラブルシューティング

### `INVALID_LOGIN: Invalid login credentials`

- Connected App のアクセスポリシーでユーザーが承認されているか確認
- コンシューマーキーが正しいか確認
- ユーザー名が正しいか確認（Sandbox は `.sandboxname` サフィックスが必要）

### `JWT_INVALID_GRANT: user hasn't approved this consumer`

- Connected App で「管理者が承認したユーザーは事前承認済み」に設定されているか確認
- プロファイルが追加されているか確認

### `INVALID_CLIENT_ID`

- Connected App 作成後、反映まで最大10分かかる場合がある
- コンシューマーキーをコピーし直す

### 証明書の有効期限切れ

```bash
# 新しい証明書を生成
openssl req -new -x509 -key server.key -out server.crt -days 365 \
  -subj "/CN=salesforce-ci/O=YourCompany"

# Salesforce の Connected App で証明書を差し替え
```

秘密鍵（`server.key`）はそのまま使えるので、GitHub Secrets の更新は不要。

## セキュリティ注意事項

- `server.key` はリポジトリにコミットしない（`.gitignore` に追加推奨）
- GitHub Secrets に登録したらローカルの `server.key` は安全に削除する
- 証明書の有効期限をカレンダーに登録しておく
- Production 環境には **Required reviewers** を設定し、手動承認を挟むことを推奨
