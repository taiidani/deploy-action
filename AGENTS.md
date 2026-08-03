# AGENTS.md

Home lab deployment configs (Docker Compose, one directory per service). See `README.md` for a quick start.

Services are deployed with [Uncloud](https://uncloud.run/docs/) (`uc deploy` in each service directory). `mise` only provides repo tooling (e.g. `fnox`) — it is not used for deploying. Exception: `servarr/` is deployed manually with `docker compose` directly on its host.

For detailed, actionable instructions, use these skills:
- **deploy-service** — deploying/registering services with Uncloud, Compose `x-` extensions (`x-ports`, `x-machines`, `x-command`), ingress
- **manage-secrets** — 1Password + fnox secrets setup and troubleshooting
