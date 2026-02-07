# Deployment Guide

This document explains how to deploy services from their individual repositories to your home lab.

## Deployment Architecture

**The Setup:**
- Services run on your home lab host (terra) at `/mnt/services`
- Each service has a `compose.yml`, optional Dockerfile, and secrets
- GitHub Actions connects via Tailscale + SSH to trigger deployments
- Docker handles artifact downloads via Dockerfile `ADD` directives

**The Flow:**
Service repo → Build artifact → Upload to S3 → Trigger deployment → SSH to terra → Docker downloads artifact during build → Service restarts

## Single Deployment Workflow

There's one workflow that handles both simple and artifact-based deployments:

### Option 1: Simple Deployment (Pre-built Images)

For services using Docker Hub images or building from source:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: taiidani/deploy-action/.github/workflows/deploy.yml@main
    with:
      service: "my-service"  # Must match directory in /mnt/services
```

### Option 2: Deployment with Binary Artifact

For Go services that build a binary and embed it in Docker:

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

## How Artifact Downloads Work

The workflow passes the artifact URL as the `ARTIFACT` build argument to Docker Compose. Your Dockerfile uses Docker's `ADD` directive to download it:

```dockerfile
ARG ARTIFACT
ADD ${ARTIFACT} /app/my-service
RUN chmod +x /app/my-service
```

**Docker's ADD directive automatically:**
- Downloads from URLs
- Extracts gzipped files
- No manual curl/gunzip needed!

## What Happens During Deployment

When the workflow runs:

1. **Connect**: Tailscale + SSH to terra
2. **Update**: `cd /mnt/services && git pull origin main`
3. **Secrets**: `mise run render-secrets`
4. **Navigate**: `cd my-service`
5. **Deploy**: `ARTIFACT=<url> docker compose up -d --build --wait`
6. **Verify**: Show status and logs

The `--build` flag ensures Docker rebuilds with the new artifact URL.
The `--wait` flag waits for services to be healthy before returning.

## Service Setup in /mnt/services

For a service to be deployable:

1. **Directory with compose.yml:**
   ```
   /mnt/services/
   └── my-service/
       ├── compose.yml
       ├── Dockerfile (if building custom image)
       └── secrets.env.tmpl (if using Vault secrets)
   ```

2. **Dockerfile that accepts ARTIFACT arg:**
   ```dockerfile
   FROM golang:1.21 AS builder
   # Download pre-built artifact
   ARG ARTIFACT
   ADD ${ARTIFACT} /app/my-service
   RUN chmod +x /app/my-service
   
   FROM debian:bookworm-slim
   COPY --from=builder /app/my-service /app/my-service
   CMD ["/app/my-service"]
   ```

3. **compose.yml:**
   ```yaml
   services:
     app:
       build:
         context: .
         dockerfile: Dockerfile
       restart: unless-stopped
       ports:
         - 3000:3000
       environment:
         DATABASE_URL: "${DATABASE_URL}"
   ```

4. **Vault secrets (if needed):**
   - Add secrets to Vault at `deploy/my-service`
   - Create `my-service/secrets.env.tmpl`
   - Register in `vault_config.hcl`

5. **Caddy ingress (if needed):**
   - Add reverse proxy block to `caddy/conf/Caddyfile`
   - Reload Caddy: `cd caddy && docker compose exec app caddy reload --config /etc/caddy/Caddyfile`

## Required Vault Secrets

Ensure these are set up in Vault:

```bash
# Tailscale OAuth credentials for GitHub Actions
vault kv put credentials/github \
  TAILSCALE_OAUTH_CLIENT_ID="..." \
  TAILSCALE_OAUTH_SECRET="..."

# SSH key for deploying to terra
vault kv put credentials/github \
  DEPLOY_SSH_KEY="$(cat ~/.ssh/id_ed25519)"

# DigitalOcean Spaces credentials (for binary publishing)
vault kv put credentials/digitalocean/spaces \
  spaces_access_id="..." \
  spaces_secret_key="..."
```

## Troubleshooting

### Deployment fails with "Permission denied"
- Check that `DEPLOY_SSH_KEY` is in Vault
- Verify the SSH key is authorized on terra: `~/.ssh/authorized_keys`

### Service fails to start
- SSH into terra and check logs: `cd /mnt/services/my-service && docker compose logs`
- Verify secrets are rendered: `ls -la .env`
- Check if service is using correct ports (no conflicts)

### Artifact download fails
- Verify artifact was uploaded to DigitalOcean Spaces
- Check the artifact URL is publicly accessible
- Test manually: `docker build --build-arg ARTIFACT=<url> .`

### Secrets not available
- Run `mise run render-secrets` on terra
- Check `vault_config.hcl` has a template block for your service
- Verify Vault token is valid: `vault token lookup`

### Build doesn't use new artifact
- Ensure you're using `docker compose up -d --build` (with `--build` flag)
- The workflow already does this, but verify in logs
- May need to add `--no-cache` if Docker is caching layers

## Tips

**Testing Locally:**
You can test the deployment on terra manually:
```bash
cd /mnt/services/my-service
ARTIFACT=https://example.com/my-binary docker compose up -d --build --wait
docker compose logs -f
```

**Dockerfile Best Practices:**
- Use multi-stage builds to keep final image small
- Use `ARG` before using variables in Dockerfile
- Docker ADD automatically handles .gz files (extracts them)
- For non-gzipped files, use ADD as-is

**Workflow Concurrency:**
- Deployments use `concurrency: group: deploy-${{ service }}` 
- Only one deployment per service runs at a time
- New deployments wait for previous ones to complete
