---
name: deploy-service
description: Deploy or register a service in taiidani's home lab deploy-action repo using mise, the centralized root Dockerfile, and Docker Compose. Use when asked to deploy a service, push out a new release, add a brand-new service, or wire up Caddy ingress for one.
---

# Deploying a Service

This repo has no GitHub Actions workflow and no separate `deployer` webhook app. All deployments are driven directly on the host by `mise` commands defined in the root `mise.toml`.

For anything related to secrets (1Password/fnox), see the `manage-secrets` skill.

## Deploying an existing service

1. Pull the latest release binary:
   ```bash
   mise up github:taiidani/<service-name>
   ```
   `mise deploy` does not refresh the tool itself — always run `mise up` first if you want the newest release.

2. Deploy:
   ```bash
   mise deploy <service-name>
   ```

The `deploy` task (defined in the root `mise.toml`):
1. Stages the binary: copies `$(which <service-name>)` (the mise-managed binary from the `github:` tool backend) into `<service-name>/artifacts/<service-name>`
2. Builds the image from the centralized root `Dockerfile`: `docker build -t taiidani/<service-name> --build-arg NAME=<service-name> .`
3. `cd`s into `<service-name>/` and runs `fnox exec --if-missing=error -- docker compose up -d --build --wait` to inject secrets and start the compose stack
4. Shows status via `fnox exec --if-missing=error -- docker compose ps`

## Adding a brand-new service

1. **Register the service's binary with mise (one-time):**
   ```bash
   mise use github:taiidani/<service-name>@latest
   ```
   This adds a `"github:taiidani/<service-name>" = "latest"` entry to the root `mise.toml` `[tools]` table.

2. **Create `<service-name>/compose.yml`:**
   ```yaml
   services:
     app:
       image: taiidani/<service-name>:latest
       restart: unless-stopped
       ports:
         - <external-port>:<internal-port>
       environment:
         KEY: "${VALUE}"
   ```
   No per-service `Dockerfile` is needed — the root `Dockerfile` handles the build for any service registered with mise.

3. **If secrets are needed**, create `<service-name>/fnox.toml` — see the `manage-secrets` skill.

4. **If HTTP access is needed, add to Caddy:**
   Edit `caddy/conf/Caddyfile`:
   ```
   <service>.taiidani.com {
     reverse_proxy {
       to 192.168.102.80:<port>
     }
   }
   ```
   Then reload Caddy (see "Caddy ingress management" below).

5. **Deploy it:**
   ```bash
   mise up github:taiidani/<service-name>
   mise deploy <service-name>
   ```

## Centralized Dockerfile

Every service shares the single root `Dockerfile` — never add a per-service `Dockerfile` for a mise-managed binary service:
```dockerfile
FROM scratch
ARG NAME
COPY artifacts/${NAME} /app
CMD ["/app"]
```

## Working with a running service locally

```bash
cd <service-name>
docker compose logs -f          # view logs
docker compose restart          # restart
docker compose down             # stop
```

Running `docker compose` directly like this does **not** inject secrets — only `mise deploy` (via `fnox exec`) does that. See the `manage-secrets` skill if you need secrets present for a manual command.

## Caddy ingress management

```bash
cd caddy
docker compose exec app caddy reload --config /etc/caddy/Caddyfile    # reload config
docker compose exec app caddy validate --config /etc/caddy/Caddyfile  # validate syntax
docker compose logs -f                                                 # view logs
```

## Volume mounts

Each service manages its own data volumes in its directory, e.g.:
```yaml
volumes:
  - ./data:/data              # Application data
  - ./data/redis:/data        # Redis data
  - ./data/config:/config     # Configuration
```

## Reference: active services

- `alloy/` - Per-host log shipper (Grafana Alloy, deployed on each host)
- `cadvisor/` - Per-host container metrics exporter (deployed on each host)
- `caddy/` - HTTP reverse proxy and ingress
- `gitea/` - Self-hosted Git service
- `groceries/` - Grocery list web app with Redis (port 3501)
- `guess-my-word/` - Word guessing game (port 3500)
- `homepage/` - Dashboard homepage
- `lil-dumpster/` - Discord bot with Redis
- `monitoring/` - Grafana + Prometheus observability stack
- `no-time-to-explain/` - Destiny 2 Discord bot with Redis (port 3502)
- `plex/` - Media server
- `redis/` - Standalone Redis instance
- `servarr/` - Media management stack (Sonarr, Radarr, etc.)
- `tfc-agent/` - Terraform Cloud agents (scaled to 2 replicas)

Services discover each other via Docker's internal DNS: `<service>.<project>_default` (e.g. `redis.groceries_default`). External services (outside Docker Compose) use static IPs (e.g. `192.168.102.80`).
