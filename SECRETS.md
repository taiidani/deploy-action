# Secrets Management

Uses 1Password + fnox to inject secrets as environment variables at runtime.

## Setup

**On host:** Create `mise.local.toml` (gitignored):
```toml
[env]
OP_SERVICE_ACCOUNT_TOKEN = "ops_eyJ..."
```

**In 1Password:** Store secrets in "Development" vault

**Per-service:** Create `<service>/fnox.toml`:
```toml
default_provider = "onepass"

[providers.onepass]
type = "1password"
vault = "Development"

[secrets]
"API_KEY" = { provider = "onepass", value = "Service Name/field" }
```

Secrets auto-inject when you run `docker compose up -d`

## GitHub Actions

**Zero GitHub secrets required!** 🎉

Both workflows use:
- **Tailscale OIDC** for network access (config hardcoded in workflows, not secrets)
- **Tailscale SSH** for authentication (no SSH keys needed)

Service repos need no secrets - they call the reusable workflows.

## Tailscale SSH Setup

**On deployment host (`terra`):**
```bash
sudo tailscale up --ssh
```

**In Tailscale admin console (ACLs):**
```json
"ssh": [
  {
    "action": "accept",
    "src": ["tag:ci"],
    "dst": ["autogroup:self"],
    "users": ["rnixon"]
  }
]
```

This allows CI runners (with `tag:ci`) to SSH as `rnixon` without any SSH keys.

## Tailscale OIDC Setup

**In Tailscale admin console:**
1. Go to Settings → OAuth clients
2. Create OAuth client with:
   - Scopes: Devices: Write
   - Tags: `tag:ci`
   - Federated identity: GitHub, repositories: `taiidani/*`

The OAuth client ID and audience are hardcoded in workflow files (they're public identifiers, not secrets).

## Troubleshooting

**Secrets not found:** Check 1Password vault has the item/field, verify `mise.local.toml` has token

**Variables empty:** Run `fnox env` to test, clear cache: `rm -rf ~/.local/share/mise/cache/`

**SSH connection fails:** Verify Tailscale SSH is enabled on host, check ACLs allow `tag:ci` to SSH