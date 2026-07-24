# 認証ガイド

> **English version**: [authentication.md](authentication.md)

このプロジェクトでは、ローカル開発に OAuth、CI/CD に JWT Bearer Flow の2つの認証方式を使用します。

## ローカル開発（OAuth）

各開発者が自分の Salesforce アカウントで認証:

```bash
sf org login web --alias sandbox --instance-url https://your-sandbox.sandbox.my.salesforce.com
```

ブラウザで OAuth ログインが開きます。サービスアカウントや管理者権限は不要です。

### 必要な権限

| 操作                           | 最低限必要な権限                                                              |
| ------------------------------ | ----------------------------------------------------------------------------- |
| メタデータ取得（参照）         | 「設定・定義の参照」または API 有効                                           |
| メタデータデプロイ（書き込み） | 「変更セットのデプロイ」または「メタデータ API 機能を使用した変更のデプロイ」 |

retrieve のみ（GUI 変更 → Git ワークフロー）であれば、API アクセスとメタデータ参照の権限セットで十分です。システム管理者は不要です。

### 推奨する権限セット

`Metadata_API_Access` という権限セットを作成:

- API 有効: true
- 設定・定義の参照: true
- メタデータ API 機能を使用した変更のデプロイ: true（デプロイが必要な場合）

ローカルで retrieve またはデプロイを行う開発者に割り当てます。

## CI/CD（JWT Bearer Flow）

CI/CD では専用のサービスユーザーと JWT 認証を使用します。セットアップ手順は [jwt-auth-setup.ja.md](jwt-auth-setup.ja.md) を参照。

### CI 専用ユーザー

CI/CD 用に専用ユーザーを作成してください（個人アカウントは使わない）:

- ユーザー名: 例 `ci-deploy@yourcompany.com` / `ci-deploy@yourcompany.com.sandbox1`
- プロファイル: システム管理者
- 目的: すべてのメタデータタイプを権限制限なくデプロイする

このユーザーは GitHub Secrets の `SF_USERNAME` として設定します。

### なぜ CI にシステム管理者が必要か？

メタデータ API のデプロイは任意のメタデータタイプ（オブジェクト、フロー、プロファイル、権限セット、ページレイアウトなど）に書き込みます。権限が制限されたユーザーでは、特定のメタデータタイプで不可解なエラーが発生します。システム管理者はこれを完全に回避します。

CI ユーザーは対話的にログインすることはなく、GitHub Actions 経由の JWT 認証でのみ使用されます。

## まとめ

| コンテキスト              | 認証方式          | ユーザー               | 権限                     |
| ------------------------- | ----------------- | ---------------------- | ------------------------ |
| ローカル retrieve         | OAuth（ブラウザ） | 開発者の個人アカウント | API + メタデータ参照     |
| ローカル deploy           | OAuth（ブラウザ） | 開発者の個人アカウント | API + メタデータ書き込み |
| CI validate（dry-run）    | JWT Bearer        | CI 専用ユーザー        | システム管理者           |
| CI deploy（Sandbox/本番） | JWT Bearer        | CI 専用ユーザー        | システム管理者           |

## セキュリティ推奨事項

- CI 専用ユーザーの認証情報を開発者と共有しない
- 各開発者はローカル作業に自分のアカウントを使う
- JWT 証明書は年1回ローテーションする（[jwt-auth-setup.ja.md](jwt-auth-setup.ja.md#証明書の有効期限切れ) 参照）
- `production` GitHub Environment に Required Reviewers を設定し、本番デプロイ前に手動承認を挟む
