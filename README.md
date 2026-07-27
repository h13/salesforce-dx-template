# Salesforce Metadata Template

[![CI](https://github.com/h13/salesforce-metadata-template/actions/workflows/ci.yml/badge.svg)](https://github.com/h13/salesforce-metadata-template/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/h13/salesforce-metadata-template/blob/main/LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D24-green.svg)](https://nodejs.org/)
[![Salesforce](https://img.shields.io/badge/Salesforce-CLI-00A1E0.svg)](https://developer.salesforce.com/tools/salesforcecli)

[日本語](README.ja.md)

**Template repository for managing Salesforce metadata with Git and CI/CD.**

Supports both GUI-based development (retrieve from org) and AI Agent-driven development (direct metadata editing). Push to `sandbox` deploys to Sandbox; push to `main` deploys to Production.

**[→ Quick Start](#quick-start)** · [Deployment Strategy](#deployment-strategy) · [Documentation](#documentation)

## The Problem

Salesforce orgs accumulate declarative customizations — flows, objects, permission sets, layouts — built through the GUI with no version history. When something breaks, there's no way to diff, revert, or review what changed. AI Agents can't safely contribute without a validation gate.

## The Solution

Pull all metadata into Git. Let CI validate every change (human or AI) before it reaches an org.

```
GUI changes   → sf retrieve → Git → PR → CI validate → merge → deploy
AI Agent edits → Git directly → PR → CI validate → merge → deploy
```

Both paths converge on the same `force-app/` directory and the same CI pipeline.

## Quick Start

### Prerequisites

- [mise](https://mise.jdx.dev/) (manages the Node.js version)
- [pnpm](https://pnpm.io/)

The [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) is bundled as a devDependency — no global install needed. Run it with `pnpm exec sf ...` after `pnpm install`.

### Setup

```bash
mise trust
mise install
pnpm install
```

Authenticate to your Sandbox:

```bash
pnpm exec sf org login web --alias sandbox --instance-url https://your-sandbox.sandbox.my.salesforce.com
```

### Retrieve GUI changes

```bash
pnpm run retrieve
```

### Validate before pushing

```bash
pnpm run validate
```

### Deploy manually

```bash
pnpm run deploy:sandbox
```

Production deploys happen only through CI/CD when changes are merged to `main`.

## Deployment Strategy

| Branch    | Target         | Trigger           |
| --------- | -------------- | ----------------- |
| `sandbox` | Sandbox org    | Automatic on push |
| `main`    | Production org | Automatic on push |

PRs to either branch run dry-run validation (`pnpm exec sf project deploy start --dry-run`) in CI.

## Project Structure

```
salesforce-metadata-template/
├── force-app/main/default/   # Salesforce metadata (source format)
│   ├── flows/                # Flow definitions
│   ├── objects/              # Custom objects and fields
│   ├── permissionsets/       # Permission sets
│   ├── layouts/              # Page layouts
│   └── ...                   # Other metadata categories
├── scripts/
│   └── retrieve.sh           # GUI change retrieval helper
├── .github/workflows/
│   ├── ci.yml                # PR validation (dry-run deploy)
│   └── deploy.yml            # Auto-deploy on push
├── docs/                     # Setup documentation
├── sfdx-project.json         # Salesforce project config (API v62.0)
├── .mise.toml                # sf CLI + Node.js version management
└── package.json              # CI tooling (oxlint, oxfmt)
```

## CI/CD Authentication

Uses JWT Bearer Flow. See [docs/jwt-auth-setup.md](docs/jwt-auth-setup.md) for step-by-step setup instructions.

Required GitHub Secrets per environment (`sandbox` / `production`):

- `SF_CLIENT_ID` — Connected App consumer key
- `SF_JWT_KEY` — Private key (PEM format)
- `SF_USERNAME` — Admin username
- `SF_INSTANCE_URL` — Instance URL

## Documentation

- [Org and Repository Model](docs/org-model.md) — One repo per Production org, multiple Sandboxes, conflict avoidance
- [Authentication Guide](docs/authentication.md) — Local vs CI/CD authentication, required permissions
- [JWT Authentication Setup](docs/jwt-auth-setup.md) — Connected App and GitHub Secrets configuration

## License

[MIT](LICENSE)
