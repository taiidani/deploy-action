# deploy-action

Home lab deployment configurations using Docker Compose and [Uncloud](https://uncloud.run/docs/).

## What's Here

- **Docker Compose services** - Each service in `<service>/compose.yml`
- **Secrets** - 1Password + fnox, resolved at deploy time by Uncloud via `x-command` entries in the compose file
- **Ingress** - Caddy reverse proxy, managed by Uncloud from `x-ports` entries (no hand-maintained Caddyfile)
- **Deployment** - Uncloud (`uc deploy`) per service; no GitHub Actions workflow or webhook listener involved
- **Tooling** - `mise` only provides repo dependencies (e.g. `fnox`); it is not used to deploy

## Quick Start

**Install repo tooling (fnox):**
```bash
mise install
```

**Deploy a service:**
```bash
cd <service-name>
uc deploy
```

**Work with a running service:**
```bash
uc ls                  # list services and endpoints
uc logs <service> -f   # stream logs
uc inspect <service>   # status and details
```

**Exception:** `servarr/` is deployed manually with plain Docker Compose directly on its host (`docker compose up -d`), not via Uncloud.

## Documentation

Detailed, actionable guidance for agents lives in this repo's skills rather than standalone docs:

- **[.agents/skills/deploy-service](.agents/skills/deploy-service/SKILL.md)** - Deploying and registering services with Uncloud, Compose `x-` extensions (`x-ports`, `x-machines`, `x-command`), ingress
- **[.agents/skills/manage-secrets](.agents/skills/manage-secrets/SKILL.md)** - 1Password + fnox secrets setup and troubleshooting
