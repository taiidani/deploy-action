# Secrets Management

This repository uses 1Password and fnox for secrets management in Docker Compose deployments.

## Overview

All services with sensitive configuration use fnox to inject environment variables from 1Password. This keeps secrets out of the repository while making them available to Docker Compose at runtime.

**How it works:**
1. mise loads the `mise-env-fnox` plugin which integrates fnox
2. fnox reads `fnox.toml` files (global and per-service)
3. fnox authenticates to 1Password using the service account token
4. fnox fetches secrets and injects them as environment variables
5. Docker Compose inherits these environment variables and passes them to containers

## Prerequisites

1. **Install mise** (if not already installed):
   ```bash
   curl https://mise.run | sh
   ```

2. **Authenticate to 1Password**:
   The service account token must be in `mise.local.toml` (gitignored):
   ```toml
   [env]
   OP_SERVICE_ACCOUNT_TOKEN = "ops_eyJ..."
   ```

3. **Verify fnox is working**:
   ```bash
   cd /mnt/services
   mise install
   fnox --help
   ```

## Running Services

When you run Docker Compose in a service directory, fnox automatically injects secrets:

```bash
cd /mnt/services/<service-name>
docker compose up -d
```

To verify what secrets are available:
```bash
cd /mnt/services/<service-name>
fnox env
```

## Configuration Files

### Global Configuration

- **`mise.toml`** - Configures fnox plugin, tools, and integration
- **`mise.local.toml`** - Contains 1Password service account token (gitignored)
- **`fnox.toml`** - Global secrets shared across services (e.g., database credentials)

See the actual files in this repository for the current configuration.

### Per-Service Configuration

Each service with secrets has a `<service>/fnox.toml` file. Examples:
- [`lil-dumpster/fnox.toml`](./lil-dumpster/fnox.toml) - Discord bot token
- [`no-time-to-explain/fnox.toml`](./no-time-to-explain/fnox.toml) - Discord + Bungie API credentials
- [`servarr/fnox.toml`](./servarr/fnox.toml) - WireGuard private key
- [`tfc-agent/fnox.toml`](./tfc-agent/fnox.toml) - Terraform Cloud token

**Secret value format:**
```toml
"VARIABLE_NAME" = { provider = "onepass", value = "Item Name/field" }
```

Common 1Password fields: `credential`, `token`, `username`, `password`, `server`, `port`

## Adding Secrets for a New Service

1. **Store secrets in 1Password** in the "Development" vault:
   - Create an item (e.g., "my-service Discord Bot")
   - Add fields for each secret (e.g., "token", "credential", "api_key")

2. **Create `<service>/fnox.toml`** - See existing service examples above for the structure

3. **Reference in `compose.yml`**:
   ```yaml
   services:
     app:
       environment:
         API_KEY: "${API_KEY}"
         DATABASE_URL: "${DATABASE_URL}"
   ```

4. **Test locally**:
   ```bash
   cd <service>
   fnox env  # Verify secrets are fetched
   docker compose up -d
   ```

## Services with 1Password Integration

**Service-specific secrets:**
- `lil-dumpster/` - Discord bot token
- `no-time-to-explain/` - Discord bot and Bungie API credentials
- `servarr/` - WireGuard private key
- `tfc-agent/` - Terraform Cloud agent token

**Global secrets** (via root `fnox.toml`):
- Database credentials used by `groceries/` and other services

## CI/CD Integration

**Current State (Transition Period):**

The GitHub Actions workflows in `.github/workflows/` currently still use Vault to fetch secrets needed for CI/CD operations (Tailscale OAuth, SSH keys, DigitalOcean Spaces credentials). These workflows use Vault's JWT authentication method with GitHub OIDC.

**On the deployment host (terra):**

Once the workflow connects to terra via SSH, mise and fnox are configured with the 1Password service account token in `mise.local.toml`. When `mise run deploy` executes, fnox automatically fetches service secrets from 1Password and injects them as environment variables for Docker Compose.

**Note:** Service deployments already use 1Password + fnox for all application secrets. Only the GitHub Actions infrastructure secrets still use Vault during this transition period.

## Troubleshooting

### Secrets not found
**Error:** `failed to get secret from provider`

**Solutions:**
- Verify item exists in 1Password "Development" vault
- Check the item name and field name match exactly (case-sensitive)
- Ensure `OP_SERVICE_ACCOUNT_TOKEN` is set in `mise.local.toml`

### Service account authentication fails
**Error:** `[ERROR] ... authentication required`

**Solutions:**
- Check that `mise.local.toml` exists and contains `OP_SERVICE_ACCOUNT_TOKEN`
- Verify the service account token is still valid
- Test with: `op account list`

### Environment variables not injecting
**Error:** Variables are empty in Docker Compose

**Solutions:**
- Run `fnox env` to verify fnox can fetch secrets
- Check that `mise.toml` includes the fnox-env plugin
- Ensure you're running Docker Compose from within the mise environment
- Try clearing the cache: `rm -rf ~/.local/share/mise/cache/`

### Permission denied accessing 1Password vault
**Error:** `insufficient permissions to access vault`

**Solutions:**
- Verify the service account has access to the "Development" vault
- Check the vault name in `fnox.toml` matches exactly
- Confirm the service account hasn't been revoked
