# Org and Repository Model

> **日本語版**: [org-model.ja.md](org-model.ja.md)

This document explains how this template relates to Salesforce orgs, how to handle multiple Sandboxes, and how to avoid conflicts when multiple people work on the same Production org.

## Core Principle: 1 Repository = 1 Production Org

Each repository created from this template manages **one Production org**. This is the single source of truth for that org's metadata.

```
┌─────────────────────────────────────────────┐
│  Git Repository                             │
│                                             │
│  main branch ──────────► Production org     │
│  sandbox branch ───────► Sandbox org (CI)   │
│                                             │
│  feature/* branches ───► local validation   │
└─────────────────────────────────────────────┘
```

Even if your organization has multiple Sandboxes (e.g., `bear`, `flamingo`, `dev1`), this repository deploys to **one designated Sandbox** for CI validation and integration testing.

## Why Not One Repository per Sandbox?

If multiple repositories deploy to the same Production org, the last deploy wins. This causes silent overwrites:

```
Repo A deploys Profile X with Permission Set A  ──► Production
Repo B deploys Profile X with Permission Set B  ──► Production (overwrites A)
```

Metadata types like Profiles, Permission Sets, and Page Layouts describe **org-wide state**. They cannot be safely split across repositories.

**Rule: One Production org = one repository. Always.**

## Multiple Sandboxes, One Repository

Your organization may have several Sandboxes for different purposes:

| Sandbox    | Purpose                  | Who uses it |
| ---------- | ------------------------ | ----------- |
| `bear`     | Development / testing    | Developer A |
| `flamingo` | UAT / stakeholder review | QA team     |
| `dev1`     | Experimental / spike     | Developer B |

All developers work in the **same repository**, on feature branches. Each developer validates against their own Sandbox locally:

```bash
# Developer A (uses bear sandbox)
pnpm exec sf org login web --alias my-sandbox --instance-url https://company--bear.sandbox.my.salesforce.com
pnpm exec sf project deploy start --dry-run --target-org my-sandbox

# Developer B (uses dev1 sandbox)
pnpm exec sf org login web --alias my-sandbox --instance-url https://company--dev1.sandbox.my.salesforce.com
pnpm exec sf project deploy start --dry-run --target-org my-sandbox
```

The CI pipeline deploys to **one shared Sandbox** (configured in GitHub Secrets) for automated validation. This is the integration Sandbox — the gatekeeper before Production.

## Branching and Deployment Flow

```
Developer A ──► feature/add-approval-flow ──┐
                                            ├──► PR to sandbox ──► CI validates ──► merge
Developer B ──► feature/update-objects ─────┘

sandbox branch ──► auto-deploy to integration Sandbox
                   (team reviews in this Sandbox)

sandbox ──► PR to main ──► auto-deploy to Production
```

### Step by step

1. **Develop**: Create a feature branch. Edit metadata or retrieve GUI changes from your personal Sandbox.
2. **Validate locally**: `pnpm exec sf project deploy start --dry-run --target-org my-sandbox`
3. **Push and PR**: Open a PR to `sandbox`. CI runs dry-run validation against the integration Sandbox.
4. **Merge to sandbox**: Changes auto-deploy to the integration Sandbox. Team verifies.
5. **Promote to Production**: Open a PR from `sandbox` to `main`. On merge, changes auto-deploy to Production.

## Handling Conflicts

Since all metadata lives in one repository, conflicts are handled by Git:

- **Same file edited by two people**: Git merge conflict → resolve in PR, re-validate.
- **Same object, different fields**: No conflict (fields are separate files in source format).
- **Profiles/Permission Sets**: These are org-wide and conflict-prone. Assign ownership (one person manages permissions) or retrieve frequently to stay in sync.

## When to Create a Separate Repository

Create a new repository from this template only when managing a **different Production org**:

| Scenario                                           | Same repo or new repo?                |
| -------------------------------------------------- | ------------------------------------- |
| Same Production org, new developer joins           | Same repo (add collaborator)          |
| Same Production org, new Sandbox created           | Same repo (developer uses it locally) |
| Different Production org (different business unit) | New repo from template                |
| Non-production experiment (throw-away)             | Optional: new repo, no `main` deploy  |

## Sandbox Lifecycle

Sandboxes may be refreshed or deleted by org admins. This does not affect the repository — the Git history is the source of truth. After a Sandbox refresh:

```bash
# Re-authenticate
pnpm exec sf org login web --alias my-sandbox --instance-url https://company--new-sandbox.sandbox.my.salesforce.com

# Re-deploy current state
pnpm exec sf project deploy start --target-org my-sandbox
```

The repository always holds the canonical state. Sandboxes are ephemeral; Git is permanent.
