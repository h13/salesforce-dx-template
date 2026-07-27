# Salesforce Metadata Template

[![CI](https://github.com/h13/salesforce-metadata-template/actions/workflows/ci.yml/badge.svg)](https://github.com/h13/salesforce-metadata-template/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/h13/salesforce-metadata-template/blob/main/LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D24-green.svg)](https://nodejs.org/)
[![Salesforce](https://img.shields.io/badge/Salesforce-CLI-00A1E0.svg)](https://developer.salesforce.com/tools/salesforcecli)

[English](README.md)

**Salesforce メタデータを Git + CI/CD で管理するためのテンプレートリポジトリ。**

GUI 操作（org から retrieve）と AI Agent による直接編集の両方に対応。`sandbox` ブランチへの push で Sandbox にデプロイ、`main` への push で Production にデプロイ。

**[→ クイックスタート](#クイックスタート)** · [デプロイ戦略](#デプロイ戦略) · [ドキュメント](#ドキュメント)

## 課題

Salesforce org には宣言的カスタマイズ（フロー、オブジェクト、権限セット、レイアウト）が蓄積されます。すべて GUI で構築され、バージョン履歴はありません。何かが壊れても、差分の確認、ロールバック、レビューができません。AI Agent もバリデーションゲートなしでは安全に貢献できません。

## 解決策

すべてのメタデータを Git に取り込む。CI で人間と AI の両方の変更を org に反映する前に検証する。

```
GUI 変更      → sf retrieve → Git → PR → CI validate → merge → deploy
AI Agent 編集 → Git に直接   → PR → CI validate → merge → deploy
```

どちらのパスも同じ `force-app/` ディレクトリと同じ CI パイプラインに合流します。

## クイックスタート

### 前提条件

- [mise](https://mise.jdx.dev/)（Node.js バージョン管理）
- [pnpm](https://pnpm.io/)

[Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) は devDependency として同梱されているため、グローバルインストールは不要。`pnpm install` 後に `pnpm exec sf ...` で実行する。

### セットアップ

```bash
mise trust
mise install
pnpm install
```

Sandbox への認証:

```bash
pnpm exec sf org login web --alias sandbox --instance-url https://your-sandbox.sandbox.my.salesforce.com
```

### GUI 変更の取り込み

```bash
pnpm run retrieve
```

### デプロイ前の検証

```bash
pnpm run validate
```

### 手動デプロイ

```bash
pnpm run deploy:sandbox
```

本番へのデプロイは `main` ブランチへのマージで CI/CD が自動実行します（ローカルからの手動デプロイは不可）。

## デプロイ戦略

| ブランチ  | デプロイ先     | トリガー      |
| --------- | -------------- | ------------- |
| `sandbox` | Sandbox org    | push 時に自動 |
| `main`    | Production org | push 時に自動 |

いずれのブランチへの PR も CI で dry-run 検証（`pnpm exec sf project deploy start --dry-run`）を実行。

## プロジェクト構成

```
salesforce-metadata-template/
├── force-app/main/default/   # Salesforce メタデータ（ソース形式）
│   ├── flows/                # フロー定義
│   ├── objects/              # カスタムオブジェクト・項目
│   ├── permissionsets/       # 権限セット
│   ├── layouts/              # ページレイアウト
│   └── ...                   # その他のメタデータカテゴリ
├── scripts/
│   └── retrieve.sh           # GUI 変更取得ヘルパー
├── .github/workflows/
│   ├── ci.yml                # PR バリデーション（dry-run deploy）
│   └── deploy.yml            # push 時の自動デプロイ
├── docs/                     # セットアップドキュメント
├── sfdx-project.json         # Salesforce プロジェクト設定（API v62.0）
├── .mise.toml                # sf CLI + Node.js バージョン管理
└── package.json              # CI ツール（oxlint, oxfmt）
```

## CI/CD 認証

JWT Bearer Flow を使用。セットアップ手順は [docs/jwt-auth-setup.ja.md](docs/jwt-auth-setup.ja.md) を参照。

GitHub Secrets（環境ごとに `sandbox` / `production` で設定）:

- `SF_CLIENT_ID` — Connected App のコンシューマーキー
- `SF_JWT_KEY` — 秘密鍵（PEM 形式）
- `SF_USERNAME` — 管理者ユーザー名
- `SF_INSTANCE_URL` — インスタンス URL

## ドキュメント

- [Org とリポジトリの運用モデル](docs/org-model.ja.md) — 1リポ = 1本番 org、複数 Sandbox の扱い、衝突回避
- [認証ガイド](docs/authentication.ja.md) — ローカル開発 vs CI/CD の認証方式、必要な権限
- [JWT 認証セットアップ](docs/jwt-auth-setup.ja.md) — Connected App と GitHub Secrets の設定手順

## ライセンス

[MIT](LICENSE)
