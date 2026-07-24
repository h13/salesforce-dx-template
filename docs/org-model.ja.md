# Org とリポジトリの運用モデル

> **English version**: [org-model.md](org-model.md)

このドキュメントでは、テンプレートと Salesforce org の関係、複数 Sandbox の扱い方、複数人で同じ本番 org を操作する際の衝突回避について説明します。

## 基本原則: 1リポジトリ = 1本番 org

このテンプレートから作成された各リポジトリは、**1つの本番 org** を管理します。これがその org のメタデータに関する唯一の信頼できる情報源（Single Source of Truth）です。

```
┌─────────────────────────────────────────────┐
│  Git リポジトリ                              │
│                                             │
│  main ブランチ ─────────► 本番 org           │
│  sandbox ブランチ ──────► Sandbox org (CI)   │
│                                             │
│  feature/* ブランチ ────► ローカル検証        │
└─────────────────────────────────────────────┘
```

組織内に複数の Sandbox（例: `bear`, `flamingo`, `dev1`）があっても、このリポジトリが CI 検証とインテグレーションテストのためにデプロイするのは**1つの指定された Sandbox** です。

## なぜ Sandbox ごとにリポジトリを分けないのか？

複数のリポジトリから同じ本番 org にデプロイすると、最後にデプロイした方が勝ちます。サイレントな上書きが発生します：

```
リポA が Profile X（権限セットA付き）をデプロイ ──► 本番
リポB が Profile X（権限セットB付き）をデプロイ ──► 本番（Aを上書き）
```

プロファイル、権限セット、ページレイアウトなどのメタデータは **org 全体の状態** を表します。リポジトリをまたいで安全に分割することはできません。

**ルール: 1つの本番 org = 1つのリポジトリ。常に。**

## 複数 Sandbox、1つのリポジトリ

組織には用途別に複数の Sandbox があるかもしれません：

| Sandbox    | 用途                          | 利用者    |
| ---------- | ----------------------------- | --------- |
| `bear`     | 開発・テスト                  | 開発者A   |
| `flamingo` | UAT・ステークホルダーレビュー | QA チーム |
| `dev1`     | 実験・スパイク                | 開発者B   |

全員が**同じリポジトリ**で、feature ブランチを使って作業します。各開発者は自分の Sandbox に対してローカルで検証します：

```bash
# 開発者A（bear sandbox を使用）
sf org login web --alias my-sandbox --instance-url https://company--bear.sandbox.my.salesforce.com
sf project deploy start --dry-run --target-org my-sandbox

# 開発者B（dev1 sandbox を使用）
sf org login web --alias my-sandbox --instance-url https://company--dev1.sandbox.my.salesforce.com
sf project deploy start --dry-run --target-org my-sandbox
```

CI パイプラインは**1つの共有 Sandbox**（GitHub Secrets で設定）に対して自動検証を行います。これがインテグレーション Sandbox — 本番への最後の門番です。

## ブランチとデプロイのフロー

```
開発者A ──► feature/add-approval-flow ──┐
                                        ├──► sandbox への PR ──► CI 検証 ──► マージ
開発者B ──► feature/update-objects ─────┘

sandbox ブランチ ──► インテグレーション Sandbox に自動デプロイ
                    （チームがこの Sandbox で確認）

sandbox ──► main への PR ──► 本番に自動デプロイ
```

### ステップバイステップ

1. **開発**: feature ブランチを作成。メタデータを編集するか、自分の Sandbox から GUI 変更を retrieve する。
2. **ローカル検証**: `sf project deploy start --dry-run --target-org my-sandbox`
3. **Push と PR**: `sandbox` への PR を作成。CI がインテグレーション Sandbox に対して dry-run 検証を実行。
4. **sandbox にマージ**: 変更がインテグレーション Sandbox に自動デプロイされる。チームが確認。
5. **本番に昇格**: `sandbox` → `main` の PR を作成。マージで本番に自動デプロイ。

## コンフリクトの扱い

すべてのメタデータが1つのリポジトリにあるため、コンフリクトは Git が処理します：

- **同じファイルを2人が編集**: Git のマージコンフリクト → PR 上で解決し、再検証。
- **同じオブジェクトの別フィールド**: コンフリクトなし（ソース形式ではフィールドごとに別ファイル）。
- **プロファイル/権限セット**: org 全体の定義なのでコンフリクトしやすい。担当者を決める（1人が権限を管理）か、頻繁に retrieve して同期を保つ。

## 別リポジトリを作るべきタイミング

このテンプレートから新しいリポジトリを作るのは、**別の本番 org** を管理する場合のみ：

| シナリオ                            | 同じリポ？ 新しいリポ？               |
| ----------------------------------- | ------------------------------------- |
| 同じ本番 org、新しい開発者が参加    | 同じリポ（コラボレーター追加）        |
| 同じ本番 org、新しい Sandbox を作成 | 同じリポ（開発者がローカルで使う）    |
| 別の本番 org（別の事業部）          | テンプレートから新しいリポ            |
| 本番以外の実験（使い捨て）          | 任意: 新しいリポ、`main` デプロイなし |

## Sandbox のライフサイクル

Sandbox は org 管理者によってリフレッシュや削除される場合があります。これはリポジトリに影響しません — Git の履歴が信頼できる情報源です。Sandbox リフレッシュ後：

```bash
# 再認証
sf org login web --alias my-sandbox --instance-url https://company--new-sandbox.sandbox.my.salesforce.com

# 現在の状態を再デプロイ
sf project deploy start --target-org my-sandbox
```

リポジトリが常に正規の状態を保持します。Sandbox は一時的なもの、Git は永続的なもの。
