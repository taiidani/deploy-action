# deploy-action

Home lab deployment configurations using Docker Compose.

## What's Here

- **Docker Compose services** - Each service in `<service>/compose.yml`
- **Secrets** - 1Password + fnox injects secrets at deploy time via explicit `fnox exec`
- **Ingress** - Caddy reverse proxy in `caddy/`
- **Deployment** - A centralized root `Dockerfile` plus a `mise deploy` task; no GitHub Actions workflow or webhook listener involved
- **Artifacts** - Binaries staged at `<service>/artifacts/` by the `mise deploy` task

## Quick Start

**Register a service's binary with mise (one-time):**
```bash
mise use github:taiidani/<service-name>@latest
```

**Pull the latest release and deploy:**
```bash
mise up github:taiidani/<service-name>
mise deploy <service-name>
```

**Work with a running service directly:**
```bash
cd <service-name>
docker compose logs -f
```

## Documentation

Detailed, actionable guidance for agents lives in this repo's skills rather than standalone docs:

- **[.agents/skills/deploy-service](.agents/skills/deploy-service/SKILL.md)** - Deploying and registering services, Dockerfile/compose patterns, Caddy ingress
- **[.agents/skills/manage-secrets](.agents/skills/manage-secrets/SKILL.md)** - 1Password + fnox secrets setup and troubleshooting
