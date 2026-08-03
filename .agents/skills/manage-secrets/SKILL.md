---
name: manage-secrets
description: Manage 1Password + fnox secrets for services in taiidani's home lab deploy-action repo. Use when asked to add a secret for a service, troubleshoot missing/empty secrets, or understand how secrets get injected during deploys.
---

# Managing Secrets with 1Password + fnox

Secrets are stored in 1Password and fetched by [fnox](https://fnox.jdx.dev). **Uncloud runs fnox for you at deploy time** — you don't wrap commands in `fnox exec` yourself. Declare a secret in the service's `compose.yml` using the `x-command` extension on a top-level `secrets:` entry, and Uncloud executes that command when deploying:

```yaml
secrets:
  GRAFANA_DISCORD_WEBHOOK:
    x-command: fnox get GRAFANA_DISCORD_WEBHOOK
```

fnox is installed locally via the root `mise.toml` (`mise install` if it's missing). For the full deploy flow this is part of, see the `deploy-service` skill.

## Configuration

- 1Password Vault: `Development`
- Authentication: `OP_SERVICE_ACCOUNT_TOKEN` in `mise.local.toml` (gitignored)
- Root `fnox.toml` holds secrets shared across multiple services
- Each service that needs its own secrets has its own `<service>/fnox.toml`

## Adding a secret to a service

1. Store the secret in the 1Password "Development" vault (create an item for the service if one doesn't exist)
2. Create or edit `<service>/fnox.toml`:
   ```toml
   default_provider = "onepass"

   [providers.onepass]
   type = "1password"
   vault = "Development"

   [secrets]
   "SECRET_NAME" = { provider = "onepass", value = "Item Name/field" }
   ```
3. Declare it in `<service>/compose.yml` so Uncloud resolves it via fnox:
   ```yaml
   secrets:
     SECRET_NAME:
       x-command: fnox get SECRET_NAME
   ```
   and reference it in the service's `environment` / secret mounts as appropriate.
4. The secret is resolved the next time `uc deploy` runs in the service directory.

fnox resolves configuration relative to the directory it runs in, so run `uc deploy` (and any manual `fnox` commands) from inside `<service>/` so that service's `fnox.toml` takes effect; otherwise the root `fnox.toml` applies.

## Testing secrets manually

```bash
cd <service-name>
fnox get SECRET_NAME            # resolve a single secret, exactly as Uncloud will
fnox exec --if-missing=error -- env | grep SECRET_NAME
```

## Troubleshooting

- **Secrets not found:** Check the 1Password vault has the item/field, verify `mise.local.toml` has `OP_SERVICE_ACCOUNT_TOKEN`
- **`fnox` not found:** Run `mise install` — fnox comes from the root `mise.toml`
- **Variables empty:** Test with `fnox get SECRET_NAME` from the service directory; clear the fnox cache if values look stale
- **Wrong secrets used:** fnox resolves relative to the directory it's invoked from — make sure you ran `uc deploy` from `<service>/`
- **Ensure item/field names in `fnox.toml` match 1Password exactly** — mismatches fail silently as missing secrets
- **servarr exception:** `servarr/` is deployed with plain `docker compose` on the host, so Uncloud does not run `x-command` for it — wrap manual commands in `fnox exec` there if secrets are needed
