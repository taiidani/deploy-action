# Deployment Guide

This document explains how to deploy services from their individual repositories to your home lab.

## Deployment Architecture

**The Setup:**
- Services run on your home lab host(s) at `/mnt/services`
- Each service has a `compose.yml`, optional Dockerfile, and secrets
- GitHub Actions connects via Tailscale + SSH to trigger deployments
- Docker handles artifact downloads via Dockerfile `ADD` directives

**The Flow:**
Service repo → Build artifact → Upload to S3 → Trigger deployment → SSH to terra → Mise deploys service → Docker downloads artifact during build → Service restarts

## Deployment Workflow

The deployment workflow requires an artifact URL. Here's the standard pattern for Go services:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      - name: Build binary
        run: go build -o my-service
      - uses: actions/upload-artifact@v4
        with:
          name: binary
          path: my-service

  publish:
    needs: build
    uses: taiidani/deploy-action/.github/workflows/publish-binary.yml@main
    with:
      artifact-name: "binary"
      filename: "my-service"

  deploy:
    needs: publish
    uses: taiidani/deploy-action/.github/workflows/deploy.yml@main
    with:
      service: "my-service"
      artifact: ${{ needs.publish.outputs.artifact }}
```

**Note:** Secrets are automatically injected by fnox when the deployment runs. See the Secrets Management section below.

## How Artifact Downloads Work

The workflow passes the artifact URL as the `ARTIFACT` build argument to Docker Compose. Your Dockerfile uses Docker's `ADD` directive with a default value:

```dockerfile
FROM scratch
ARG ARTIFACT=https://rnd-public.sfo3.digitaloceanspaces.com/taiidani/my-service/latest
ADD --unpack ${ARTIFACT} /app/
CMD ["/app/my-service"]
```

**How this works:**
- CI/CD always passes the specific artifact URL (e.g., `my-service-2024.01.15.tgz`)
- Local development omits the artifact arg, so Docker uses the default "latest.tgz"
- The publish workflow uploads both the versioned file AND a "latest.tgz" copy
- `ADD --unpack` automatically downloads and extracts gzipped tarballs

## What Happens During Deployment

When the workflow runs:

1. **Connect**: Tailscale + SSH to terra
2. **Execute**: `cd /mnt/services && mise run deploy <service> <artifact-url>`

The Mise task handles:
- Pulling latest configurations from git
- Injecting secrets via fnox (automatically)
- Building/starting the service with Docker Compose
- Showing deployment status and logs

**You can run the same command locally:**
```bash
# On terra or locally with the repo
cd /mnt/services
mise run deploy groceries
mise run deploy groceries https://example.com/binary.gz
```

This approach means the deployment logic lives in `.mise.toml`, not scattered across GitHub Actions.

## Service Setup in /mnt/services

For a service to be deployable:

1. **Directory with compose.yml:**
   ```
   /mnt/services/
   └── my-service/
       ├── compose.yml
       ├── Dockerfile (if building custom image)
       └── fnox.toml (if service needs secrets)
   ```

2. **Dockerfile that accepts ARTIFACT arg with default:**
   ```dockerfile
   FROM scratch
   ARG ARTIFACT=https://rnd-public.sfo3.digitaloceanspaces.com/taiidani/my-service/latest.tgz
   ADD --unpack ${ARTIFACT} /app/
   CMD ["/app/my-service"]
   ```
   
   Or with Alpine for CA certificates:
   ```dockerfile
   FROM alpine:latest
   RUN apk --no-cache add ca-certificates
   ARG ARTIFACT=https://rnd-public.sfo3.digitaloceanspaces.com/taiidani/my-service/latest.tgz
   ADD --unpack ${ARTIFACT} /app/
   CMD ["/app/my-service"]
   ```

3. **compose.yml:**
   ```yaml
   services:
     app:
       build:
         context: .
         dockerfile: Dockerfile
         args:
           ARTIFACT: ${ARTIFACT}
       restart: unless-stopped
       ports:
         - 3000:3000
       environment:
         DATABASE_URL: "${DATABASE_URL}"
   ```
   
   The `args: ARTIFACT: ${ARTIFACT}` passes the environment variable to the Dockerfile's `ARG`.

4. **1Password secrets (if needed):**
   - Add secrets to 1Password "Development" vault (create an item for the service)
   - Create `my-service/fnox.toml`:
     ```toml
     default_provider = "onepass"
     
     [providers.onepass]
     type = "1password"
     vault = "Development"
     
     [secrets]
     "SECRET_NAME" = { provider = "onepass", value = "Item Name/field" }
     ```
   - Reference in compose.yml: `environment: SECRET_NAME: "${SECRET_NAME}"`

5. **Caddy ingress (if needed):**
   - Add reverse proxy block to `caddy/conf/Caddyfile`
   - Reload Caddy: `cd caddy && docker compose exec app caddy reload --config /etc/caddy/Caddyfile`

## Required Secrets

**1Password "Development" Vault:**
- Service-specific items with credentials (e.g., "my-service Discord Bot")
- Database credentials (referenced in root `fnox.toml`)
- DigitalOcean Spaces credentials (for binary publishing)

**mise.local.toml (on host):**
```toml
[env]
OP_SERVICE_ACCOUNT_TOKEN = "ops_eyJ..."
```

**GitHub Secrets (for CI/CD workflows):**
- `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_SECRET` - For Tailscale connection
- `DEPLOY_SSH_KEY` - SSH private key for connecting to host
- `OP_SERVICE_ACCOUNT_TOKEN` - 1Password service account token (for workflows that need secrets)

## Troubleshooting

### Deployment fails with "Permission denied"
- Check that `DEPLOY_SSH_KEY` is configured in GitHub Secrets
- Verify the SSH key is authorized on host: `~/.ssh/authorized_keys`

### Service fails to start
- SSH into host and check logs: `cd /mnt/services/my-service && docker compose logs`
- Verify secrets are injected: `cd /mnt/services/my-service && fnox env`
- Check if service is using correct ports (no conflicts)

### Artifact download fails
- Verify artifact was uploaded to DigitalOcean Spaces
- Check the artifact URL is publicly accessible
- Test manually: `docker build --build-arg ARTIFACT=<url> .`

### Secrets not available
- Verify `fnox.toml` exists in the service directory
- Check secrets exist in 1Password "Development" vault
- Test secret fetching: `cd /mnt/services/my-service && fnox env`
- Verify `OP_SERVICE_ACCOUNT_TOKEN` is set in `mise.local.toml`
- Ensure item names and field names in `fnox.toml` match 1Password exactly

### Build doesn't use new artifact
- Ensure you're using `docker compose up -d --build` (with `--build` flag)
- The workflow already does this, but verify in logs
- May need to add `--no-cache` if Docker is caching layers

## Tips

**Testing Deployments Locally:**
Use the same Mise task that GitHub Actions uses:
```bash
cd /mnt/services

# Deploy with latest artifact (Dockerfile default)
mise run deploy my-service

# Deploy with specific artifact
mise run deploy my-service https://example.com/my-binary.gz
```

The first command (without artifact URL) uses the Dockerfile's default `ARG`, which points to the "latest" uploaded artifact.

**Manual Docker Compose:**
You can also work with Docker Compose directly:
```bash
cd /mnt/services/my-service
ARTIFACT=https://example.com/my-binary docker compose up -d --build --wait
docker compose logs -f
```

**Dockerfile Best Practices:**
- Use `ARG ARTIFACT=...` with a default pointing to "latest.tgz"
- Use `ADD --unpack` for automatic download and extraction
- Use `FROM scratch` for minimal image size (Go binaries)
- Use `FROM alpine:latest` if you need CA certificates
- The "latest.tgz" artifact is updated by the publish workflow on every push

**Workflow Concurrency:**
- Deployments use `concurrency: group: deploy-${{ service }}` 
- Only one deployment per service runs at a time
- New deployments wait for previous ones to complete
