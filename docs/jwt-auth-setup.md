# JWT Bearer Flow Authentication Setup

> **日本語版**: [jwt-auth-setup.ja.md](jwt-auth-setup.ja.md)

Step-by-step guide to configure JWT Bearer Flow for CI/CD deployment to Salesforce orgs.

## Overview

```
GitHub Actions → JWT authentication → Deploy to Salesforce org
```

Requirements:

- Admin access to Salesforce org
- OpenSSL (for key generation)
- Access to GitHub repository Settings

## 1. Generate Private Key and Certificate

Run locally:

```bash
# Generate private key
openssl genrsa -out server.key 2048

# Generate certificate (valid for 365 days)
openssl req -new -x509 -key server.key -out server.crt -days 365 \
  -subj "/CN=salesforce-ci/O=YourCompany"
```

`server.key` is used in CI. `server.crt` is uploaded to Salesforce.

## 2. Create Connected App in Salesforce

### Configure in Sandbox org

1. **Setup** → Quick Find: "App Manager"
2. Click **New Connected App**
3. Fill in:
   - Connected App Name: `CI Deploy`
   - API Name: `CI_Deploy`
   - Contact Email: admin email
4. Check **Enable OAuth Settings**
5. Configure:
   - Callback URL: `https://login.salesforce.com/services/oauth2/callback`
   - Check **Use digital signatures** → upload `server.crt`
   - OAuth Scopes:
     - `Manage user data via APIs (api)`
     - `Manage user data via Web browsers (web)`
     - `Perform requests at any time (refresh_token, offline_access)`
6. **Save**

### Configure Access Policy

1. Open the Connected App
2. **Manage Policies** → **Edit**
3. Permitted Users: **Admin approved users are pre-authorized**
4. **Save**
5. In **Profiles** section, add "System Administrator"

### Get Consumer Key

1. On the Connected App detail page, click **Manage Consumer Details**
2. Copy the **Consumer Key** (this is `SF_CLIENT_ID`)

## 3. Repeat for Production Org

Create the same Connected App in Production. Using the same `server.crt` allows the same private key to authenticate to both orgs.

## 4. Configure GitHub Secrets

In repository **Settings** → **Environments**, create two environments:

### `sandbox` environment

| Secret            | Value                                                                  |
| ----------------- | ---------------------------------------------------------------------- |
| `SF_CLIENT_ID`    | Connected App consumer key                                             |
| `SF_JWT_KEY`      | Contents of `server.key` (full PEM text)                               |
| `SF_USERNAME`     | Sandbox admin username (e.g., `admin@company.com.sandbox1`)            |
| `SF_INSTANCE_URL` | Sandbox URL (e.g., `https://mycompany--dev.sandbox.my.salesforce.com`) |

### `production` environment

| Secret            | Value                                                        |
| ----------------- | ------------------------------------------------------------ |
| `SF_CLIENT_ID`    | Production Connected App consumer key                        |
| `SF_JWT_KEY`      | Same `server.key` contents                                   |
| `SF_USERNAME`     | Production admin username (e.g., `admin@company.com`)        |
| `SF_INSTANCE_URL` | Production URL (e.g., `https://mycompany.my.salesforce.com`) |

### Repository-level Secrets (for CI validation)

The PR validate job runs outside environments, so Sandbox secrets are also needed at the repository level:

| Secret                    | Value                              |
| ------------------------- | ---------------------------------- |
| `SF_CLIENT_ID`            | Sandbox Connected App consumer key |
| `SF_JWT_KEY`              | Contents of `server.key`           |
| `SF_SANDBOX_USERNAME`     | Sandbox admin username             |
| `SF_SANDBOX_INSTANCE_URL` | Sandbox URL                        |

## 5. Test Authentication Locally

```bash
pnpm exec sf org login jwt \
  --client-id YOUR_CLIENT_ID \
  --jwt-key-file server.key \
  --username admin@company.com.sandbox1 \
  --instance-url https://mycompany--dev.sandbox.my.salesforce.com \
  --alias sandbox
```

On success:

```
Successfully authorized admin@company.com.sandbox1 with org ID 00D...
```

## 6. Verify

```bash
# Dry-run deploy to Sandbox
pnpm exec sf project deploy start --dry-run --target-org sandbox --wait 30
```

## Troubleshooting

### `INVALID_LOGIN: Invalid login credentials`

- Verify the Connected App access policy authorizes the user
- Confirm the consumer key is correct
- Confirm the username is correct (Sandbox requires `.sandboxname` suffix)

### `JWT_INVALID_GRANT: user hasn't approved this consumer`

- Verify "Admin approved users are pre-authorized" is set
- Verify the profile is added to the Connected App

### `INVALID_CLIENT_ID`

- Connected App creation can take up to 10 minutes to propagate
- Re-copy the consumer key

### Certificate expiration

```bash
# Generate new certificate
openssl req -new -x509 -key server.key -out server.crt -days 365 \
  -subj "/CN=salesforce-ci/O=YourCompany"

# Replace certificate in the Salesforce Connected App
```

The private key (`server.key`) remains unchanged, so no GitHub Secrets update is needed.

## Security Notes

- Never commit `server.key` to the repository (add to `.gitignore`)
- Delete local `server.key` after registering it in GitHub Secrets
- Set a calendar reminder for certificate expiration
- Add **Required reviewers** to the `production` environment for manual approval
