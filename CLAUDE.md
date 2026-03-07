# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains deployment configurations for taiidani's home lab. All services run using Docker Compose on a single home lab host. The repository provides:
1. Docker Compose configurations for all services
2. 1Password + fnox integration for secrets management
3. Caddy reverse proxy for HTTP ingress
4. GitHub Actions workflows for CI/CD (uses Tailscale OIDC, no static credentials)
5. Artifacts uploaded to `<service>/artifacts/` (within service directory)

## Architecture

### Docker Compose Services

Each service has its own directory containing a `compose.yml` or `docker-compose.yml` file. Services are deployed and managed independently on the home lab host.

**Active Services:**
- `beszel/` - System monitoring service
- `caddy/` - HTTP reverse proxy and ingress
- `gitea/` - Self-hosted Git service
- `groceries/` - Grocery list web app with Redis
- `guess-my-word/` - Word guessing game
- `homepage/` - Dashboard homepage
- `lil-dumpster/` - Discord bot with Redis
- `no-time-to-explain/` - Destiny 2 Discord bot with Redis
- `plex/` - Media server
- `redis/` - Standalone Redis instance
- `servarr/` - Media management stack (Sonarr, Radarr, etc.)
- `tfc-agent/` - Terraform Cloud agents (scaled to 2 replicas)

### Secrets Management with 1Password + fnox

Secrets are managed using 1Password and fnox, which injects environment variables at runtime.

**Configuration:**
- 1Password Vault: `Development`
- Authentication: Service account token in `mise.local.toml`
- Integration: `mise-env-fnox` plugin automatically loads secrets

**Configuration Pattern:**
Each service with secrets has:
1. A configuration file: `<service>/fnox.toml`
2. Secrets stored in 1Password "Development" vault
3. Environment variables automatically injected by fnox

**How it works:**
When you run Docker Compose, fnox automatically:
1. Reads `fnox.toml` to determine which secrets to fetch
2. Authenticates to 1Password using the service account token
3. Fetches secrets and injects them as environment variables
4. Docker Compose inherits these variables

**fnox.toml Example (`<service>/fnox.toml`):**
```toml
default_provider = "onepass"

[providers.onepass]
type = "1password"
vault = "Development"

[secrets]
"DATABASE_URL" = { provider = "onepass", value = "service-name Database/url" }
"API_KEY" = { provider = "onepass", value = "service-name API/credential" }
```

### Ingress with Caddy

HTTP ingress is handled by Caddy in `caddy/compose.yml`. The Caddyfile is located at `caddy/conf/Caddyfile`.

**Caddy Configuration:**
- Ports: 80, 443 (TCP and UDP for HTTP/3)
- Volumes: `./conf` mounted to `/etc/caddy/`, persistent data in `./data/`
- ACME email: `rnixon@taiidani.com`
- Storage: File system at `/data/caddy`

**Routing Pattern:**
Services are accessed via subdomains and reverse proxied to internal ports:
```
groceries.taiidani.com {
  reverse_proxy {
    to 192.168.102.5:3501
  }
}
```

Common service ports:
- `guess-my-word`: 3500
- `groceries`: 3501
- `no-time-to-explain`: 3502

### Service Patterns

**Web Applications with Dependencies:**
Services like `groceries/` and `no-time-to-explain/` include their own Redis instances:
```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - 3501:3000
    environment:
      REDIS_HOST: redis.groceries_default
      REDIS_PORT: "6379"
      DATABASE_URL: "${DATABASE_URL}"
      
  redis:
    image: redis:7
    restart: unless-stopped
    volumes:
      - ./data/redis:/data
```

**Service Discovery:**
Services discover each other using Docker's internal DNS:
- Format: `<service>.<project>_default` (e.g., `redis.groceries_default`)
- External services use static IPs (e.g., `192.168.102.5`)

**Environment Variables:**

Secrets are injected by fnox at runtime (no `.env` files needed)

## Development Commands

### Mise Tasks

All deployment logic is defined in `mise.toml` for consistency between CI/CD and local development.

**Deploy a service:**
```bash
# Deploy with latest artifact (uses Dockerfile default)
mise run deploy <service-name>

# Deploy with specific artifact
mise run deploy <service-name> https://example.com/artifact.gz
```

This task handles the full deployment:
- Pulls latest git changes
- Injects secrets via fnox (automatically)
- Deploys with `docker compose up -d --build --wait`
- Shows status and logs

**Note:** When no artifact is specified, the Dockerfile's default `ARG` points to the "latest" uploaded artifact for that service.

**Available Mise tasks:**
```bash
mise tasks  # List all available tasks
```

### Working with Services Locally

Start a service:
```bash
cd <service-directory>
docker compose up -d
```

View logs:
```bash
docker compose logs -f
```

View logs for specific service:
```bash
docker compose logs -f <service-name>
```

Stop a service:
```bash
docker compose down
```

Restart a service:
```bash
docker compose restart
```

Rebuild and restart:
```bash
docker compose up -d --build
```

### Secrets Management

Add secrets to a new service:
1. Store secrets in 1Password "Development" vault (create an item for the service)
2. Create `<service>/fnox.toml`:
   ```toml
   default_provider = "onepass"
   
   [providers.onepass]
   type = "1password"
   vault = "Development"
   
   [secrets]
   "SECRET_NAME" = { provider = "onepass", value = "Item Name/field" }
   ```
3. Reference in `compose.yml` with `${SECRET_NAME}`
4. Secrets are automatically injected when running Docker Compose

### Caddy Management

Reload Caddy configuration:
```bash
cd caddy
docker compose exec app caddy reload --config /etc/caddy/Caddyfile
```

Test Caddyfile syntax:
```bash
cd caddy
docker compose exec app caddy validate --config /etc/caddy/Caddyfile
```

View Caddy logs:
```bash
cd caddy
docker compose logs -f
```

## Key Patterns

### Adding a New Service

1. **Create service directory with compose file:**
   ```bash
   mkdir <service-name>
   cd <service-name>
   ```

2. **Create `compose.yml`:**
   ```yaml
   services:
     app:
       image: <image>
       # or build:
       #   context: .
       #   dockerfile: Dockerfile
       restart: unless-stopped
       ports:
         - <external-port>:<internal-port>
       environment:
         KEY: "${VALUE}"  # Loaded from .env
   ```

3. **If secrets are needed, create fnox.toml:**
   ```bash
   # Create fnox.toml
   cat > fnox.toml <<EOF
   default_provider = "onepass"
   
   [providers.onepass]
   type = "1password"
   vault = "Development"
   
   [secrets]
   "SECRET_NAME" = { provider = "onepass", value = "Service Name/field" }
   EOF
   
   # Add secrets to 1Password "Development" vault
   ```

4. **If HTTP access is needed, add to Caddy:**
   Edit `caddy/conf/Caddyfile`:
   ```
   <service>.taiidani.com {
     reverse_proxy {
       to 192.168.102.5:<port>
     }
   }
   ```
   Then reload Caddy: `cd caddy && docker compose exec app caddy reload --config /etc/caddy/Caddyfile`

5. **Start the service:**
   ```bash
   cd <service-name>
   docker compose up -d
   ```

### Deployment Workflows

**Manual Deployment (on host):**
1. Pull latest changes on the host
2. Navigate to service directory
3. Pull new images or rebuild: `docker compose pull` or `docker compose build`
4. Restart service: `docker compose up -d` (fnox automatically injects secrets)
5. Check logs: `docker compose logs -f`

**CI/CD Deployment:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ...

      - uses: actions/upload-artifact@v4
        with:
          name: binary
          path: my-service.tgz

  publish:
    needs: build
    uses: taiidani/deploy-action/.github/workflows/publish-binary.yml@main
    with:
      artifact-name: "binary"
      filename: "my-service.tgz"
  
  deploy:
    needs: publish
    uses: taiidani/deploy-action/.github/workflows/deploy.yml@main
    with:
      service: "my-service"
      artifact: ${{ needs.publish.outputs.artifact }}
```

### Volume Mounts

**Persistent Data:**
Each service manages its own data volumes in its directory:
```yaml
volumes:
  - ./data:/data              # Application data
  - ./data/redis:/data        # Redis data
  - ./data/config:/config     # Configuration
```

**Caddy Persistence:**
Caddy stores certificates and configuration in:
- `./data/data` - Certificate storage
- `./data/config` - Caddy's internal config

## GitHub Workflows

### Reusable Workflows

**`.github/workflows/deploy.yml`** - Docker Compose deployment:
- Requires an artifact URL as input
- Connects to home lab via Tailscale and SSH
- Executes: `mise run deploy <service> <artifact-url>`
- Deployment logic is in `mise.toml` for consistency
- Can be run locally with the same command

**`.github/workflows/publish-binary.yml`** - Uploads artifacts to `/mnt/services/artifacts/<service>/`

### Required Secrets

- **On host:** `OP_SERVICE_ACCOUNT_TOKEN` in `mise.local.toml` for 1Password
- **GitHub:** Zero secrets required! 🎉
- **Tailscale:** Uses OIDC + Tailscale SSH (config hardcoded in workflows, not secrets)

**Dockerfile pattern:**
```dockerfile
FROM scratch
ARG ARTIFACT=artifacts/latest.tgz
ADD --unpack ${ARTIFACT} /app/
CMD ["/app/my-service"]
```

**compose.yml:**
```yaml
services:
  app:
    build:
      context: .
      args:
        ARTIFACT: ${ARTIFACT}
```

CI/CD passes the specific artifact path. Local dev uses default `latest.tgz`.

## Archived Components

**`archive/jobs/`** - Old Nomad jobspecs (historical reference)
**`archive/dockge/`**, **`archive/jellyfin/`** - Deprecated service configurations

## Secrets Management

Secrets are managed using 1Password and fnox. See [SECRETS.md](./SECRETS.md) for detailed documentation.

**Current Setup:**
- 1Password "Development" vault stores all secrets
- fnox fetches secrets and injects as environment variables
- mise integrates fnox via the `mise-env-fnox` plugin
- Service-specific `fnox.toml` files define which secrets to fetch

**Key Files:**
- `mise.toml` - Configures fnox integration and tools
- `mise.local.toml` - Contains 1Password service account token (gitignored)
- `fnox.toml` - Global secrets (e.g., database credentials)
- `<service>/fnox.toml` - Per-service secrets configuration
