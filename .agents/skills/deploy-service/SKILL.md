---
name: deploy-service
description: Deploy or register a service in taiidani's home lab deploy-action repo using Uncloud (`uc`) and Docker Compose. Use when asked to deploy a service, push out a new release, add a brand-new service, or wire up ingress for one.
---

# Deploying a Service

Deployments are driven by [Uncloud](https://uncloud.run/docs/) (`uc` CLI), which deploys each service's `compose.yml` across the cluster. Uncloud manages the Caddy reverse proxy itself — there is no hand-maintained Caddyfile.

`mise` is **not** used for deploying. It only provides repo tooling dependencies (e.g. `fnox`) via the root `mise.toml`.

For anything related to secrets (1Password/fnox), see the `manage-secrets` skill.

## Deploying an existing service

```bash
cd <service-name>
uc deploy
```

`uc deploy` reads the local `compose.yml`, prints a deployment plan (what containers will be created/replaced/removed, and on which machines), asks for confirmation, and performs zero-downtime rolling updates (`start-first` ordering).

Useful follow-ups:

```bash
uc ls                    # list services and their public endpoints
uc inspect <service>     # status/details of a service
uc logs <service> -f     # stream logs
uc rm <service>          # remove a service
```

## Adding a brand-new service

1. **Create `<service-name>/compose.yml`:**
   ```yaml
   services:
     app:
       image: <image>:<tag>
       restart: unless-stopped
       x-ports:
         - <service>.taiidani.com:<internal-port>/https   # public HTTPS via Uncloud's Caddy
       # x-machines: <machine-name>                       # pin to a specific machine, if needed
       environment:
         KEY: "${VALUE}"
   ```

2. **If secrets are needed**, create `<service-name>/fnox.toml` and declare the secret in the compose file — see the `manage-secrets` skill.

3. **Deploy it:**
   ```bash
   cd <service-name>
   uc deploy
   ```

## Uncloud Compose extensions

Uncloud extends the Compose format with `x-` keys used throughout this repo:

- **`x-ports`** — port publishing:
  - `domain:port/https` — public HTTPS endpoint through Uncloud's managed Caddy (e.g. `taiidani.com:3000/https`)
  - `"8081:8080/tcp@host"` — publish directly on the host's network interface (LAN-only, no ingress)
- **`x-machines`** — pin a service to a specific machine (e.g. `x-machines: monitoring`)
- **`x-command`** (on `secrets:` entries) — command Uncloud runs to resolve a secret value (e.g. `x-command: fnox get GRAFANA_DISCORD_WEBHOOK`)
- **`deploy.mode: global`** — run one container per machine (used by per-host agents like `alloy/` and `cadvisor/`)

## Ingress

Uncloud runs Caddy as a cluster service and configures it automatically from `x-ports` entries. To expose a service over HTTPS, add a `domain:port/https` entry to `x-ports` and run `uc deploy` — no manual Caddyfile edits or reloads.

## Exception: servarr

`servarr/` is **not** deployed through Uncloud. It runs directly on its host with plain Docker Compose:

```bash
cd servarr
docker compose up -d
```

Its compose file uses features Uncloud doesn't manage (e.g. `network_mode: service:gluetun` for VPN-routed traffic). Treat it as a manually-managed stack.

## Volume mounts

Services store persistent data on the host, typically under `/data/<service>/...`:

```yaml
volumes:
  - /data/monitoring/tempo:/var/tempo
```

## Reference: active services

- `alloy/` - Per-host log shipper (Grafana Alloy, `deploy.mode: global`)
- `cadvisor/` - Per-host container metrics exporter (`deploy.mode: global`)
- `caddy/` - HTTP reverse proxy (managed by Uncloud)
- `gitea/` - Self-hosted Git service
- `homepage/` - Dashboard homepage
- `immich/` - Photo management
- `lil-dumpster/` - Discord bot with Redis
- `monitoring/` - Grafana + Prometheus + Loki + Tempo observability stack (pinned to the `monitoring` machine)
- `plex/` - Media server (pinned to the `media` machine)
- `redis/` - Standalone Redis instance
- `servarr/` - Media management stack (Sonarr, Radarr, etc.) — **manual `docker compose`, not Uncloud**
- `tfc-agent/` - Terraform Cloud agents

Services discover each other via cluster DNS by service name. Host-published ports use the `@host` suffix in `x-ports`.
