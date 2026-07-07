---
name: manage-secrets
description: Manage 1Password + fnox secrets for services in taiidani's home lab deploy-action repo. Use when asked to add a secret for a service, troubleshoot missing/empty secrets, or understand how secrets get injected during deploys.
---

# Managing Secrets with 1Password + fnox

Secrets are stored in 1Password and fetched by fnox. fnox is **not** auto-injected globally — there's no `mise-env-fnox` plugin or root `[env]` auto-injection, and it doesn't run just from `cd`-ing into a service directory. It's invoked explicitly, once, by the `deploy` task in the root `mise.toml`, wrapping only the `docker compose` command it runs:

```bash
fnox exec --if-missing=error -- docker compose up -d --build --wait
```

For the full deploy flow this is part of, see the `deploy-service` skill.

## Configuration

- 1Password Vault: `Development`
- Authentication: `OP_SERVICE_ACCOUNT_TOKEN` in `mise.local.toml` (gitignored)
- Root `fnox.toml` holds secrets shared across multiple services (e.g. the shared Postgres `DATABASE_USER`/`DATABASE_PASS`)
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
3. Reference it in `<service>/compose.yml` with `${SECRET_NAME}`
4. The secret is injected the next time `mise deploy <service-name>` runs `fnox exec -- docker compose ...`

## Testing secrets manually

```bash
cd <service-name>
fnox exec --if-missing=error -- env | grep SECRET_NAME
```

## Troubleshooting

- **Secrets not found:** Check the 1Password vault has the item/field, verify `mise.local.toml` has `OP_SERVICE_ACCOUNT_TOKEN`
- **Variables empty:** Test with `fnox exec -- env`, clear cache: `rm -rf ~/.local/share/mise/cache/`
- **Wrong secrets used:** fnox resolves relative to the directory it's invoked from. The `deploy` task `cd`s into `<service>/` first, so that service's `fnox.toml` (if present) takes effect for that deploy; otherwise the root `fnox.toml` applies
- **Ensure item/field names in `fnox.toml` match 1Password exactly** — mismatches fail silently as missing secrets
