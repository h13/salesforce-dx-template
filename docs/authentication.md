# Authentication Guide

> **日本語版**: [authentication.ja.md](authentication.ja.md)

This project uses two authentication methods: OAuth for local development and JWT Bearer Flow for CI/CD.

## Local Development (OAuth)

Each developer authenticates with their own Salesforce account:

```bash
pnpm exec sf org login web --alias sandbox --instance-url https://your-sandbox.sandbox.my.salesforce.com
```

This opens a browser for OAuth login. No service account or admin credentials needed.

### Required Permissions

| Operation                | Minimum Permission                                                       |
| ------------------------ | ------------------------------------------------------------------------ |
| Retrieve metadata (read) | "View Setup and Configuration" or API Enabled                            |
| Deploy metadata (write)  | "Deploy Change Sets" or "Modify Metadata Through Metadata API Functions" |

For retrieve-only users (GUI changes → Git workflow), a permission set with API access and metadata read is sufficient. System Administrator is not required.

### Recommended Permission Set

Create a permission set called `Metadata_API_Access` with:

- API Enabled: true
- View Setup and Configuration: true
- Modify Metadata Through Metadata API Functions: true (for deploy)

Assign it to developers who need to retrieve or deploy locally.

## CI/CD (JWT Bearer Flow)

CI/CD uses a dedicated service user with JWT authentication. See [jwt-auth-setup.md](jwt-auth-setup.md) for full setup instructions.

### CI Service User

Create a dedicated user for CI/CD (do not reuse personal accounts):

- Username: e.g., `ci-deploy@yourcompany.com` / `ci-deploy@yourcompany.com.sandbox1`
- Profile: System Administrator
- Purpose: deploy all metadata types without permission restrictions

This user is referenced in GitHub Secrets as `SF_USERNAME`.

### Why System Administrator for CI?

Metadata API deployment can touch any metadata type — objects, flows, profiles, permission sets, page layouts, etc. A restricted user may fail on certain metadata types with cryptic errors. System Administrator avoids this entirely.

The CI user never logs in interactively; it only authenticates via JWT in GitHub Actions.

## Summary

| Context                        | Auth Method     | User                    | Permissions          |
| ------------------------------ | --------------- | ----------------------- | -------------------- |
| Local retrieve                 | OAuth (browser) | Developer's own account | API + metadata read  |
| Local deploy                   | OAuth (browser) | Developer's own account | API + metadata write |
| CI validation (dry-run)        | JWT Bearer      | CI service user         | System Administrator |
| CI deploy (Sandbox/Production) | JWT Bearer      | CI service user         | System Administrator |

## Security Recommendations

- Never share the CI service user credentials with developers
- Each developer uses their own account for local work
- Rotate the JWT certificate annually (see [jwt-auth-setup.md](jwt-auth-setup.md#certificate-expiration))
- Add Required Reviewers to the `production` GitHub Environment for manual approval before production deploys
