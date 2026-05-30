# Deployment Guide

This document explains how to deploy services from their individual repositories to your home lab.

## Deployment Architecture

**The Setup:**
- Services run on your home lab host(s) at `/mnt/services`
- Each service has a `compose.yml`, optional Dockerfile, and secrets
- GitHub Actions connects via Tailscale OIDC + SSH to trigger deployments
- The host downloads artifacts directly from GitHub using `gh run download`
- Docker builds from local artifacts via Dockerfile `ADD` directives

**The Flow:**
Service repo → Build artifact → Upload to GitHub Actions → Trigger deployment → SSH to terra → Mise downloads artifact via `gh` → Docker builds from local artifact → Service restarts

## Deployment Workflow

The deployment workflow uses GitHub Actions artifacts. Here's the standard pattern for Go services:

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
        run: go build -o my-service && tar -czf my-service.tgz my-service
      - uses: actions/upload-artifact@v4
        with:
          name: artifact
          path: my-service.tgz

  deploy:
    needs: build
    uses: taiidani/deploy-action/.github/workflows/deploy.yml@main
    with:
      artifact-name: "artifact"
      filename: "my-service.tgz"
```

**Note:** Secrets are automatically injected by fnox when the deployment runs. See the Secrets Management section below.

## How Artifact Downloads Work

The reusable workflow SSHs into the deploy host and runs:
```bash
mise run deploy <service> --artifact-name <name> --filename <filename> --run-id <run-id>
```

This task:
1. Uses `gh run download` to fetch the artifact from GitHub Actions
2. Stores it in `<service>/artifacts/<filename>` (and copies to `latest.tgz`)
3. Passes `ARTIFACT=artifacts/<filename>` to Docker Compose
4. Docker's `ADD --unpack` extracts the local tarball into the image

**Dockerfile pattern:**
```dockerfile
FROM scratch
ARG ARTIFACT
ADD --unpack ${ARTIFACT} /app/
CMD ["/app/my-service"]
```

**compose.yml pattern:**
```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        ARTIFACT: ${ARTIFACT:-https://fallback-url.example.com/latest.tgz}
```

The `ARTIFACT` default in `compose.yml` provides a fallback URL for local development when no artifact is specified.

## What Happens During Deployment

When the workflow runs:

1. **Connect**: Tailscale OIDC + SSH to terra (zero secrets needed in GitHub)
2. **Execute**: `cd /mnt/services && mise run deploy <service> --filename <filename> --run-id <run-id>`

The `deploy` Mise task handles:
- Downloading the artifact from GitHub via `gh run download`
- Storing it locally in the service's `artifacts/` directory
- Injecting secrets via fnox (automatically)
- Building/starting the service with Docker Compose
- Showing deployment status

**You can run the same commands locally:**
```bash
# On terra or locally with the repo
cd /mnt/services

# Deploy without artifact (uses Dockerfile default fallback URL)
mise run deploy groceries

# Deploy with a local artifact
mise run deploy groceries artifacts/groceries.tgz

# Deploy by downloading from GitHub Actions
mise run deploy groceries --filename groceries.tgz --run-id 12345678
```

This approach means the deployment logic lives in `mise.toml`, not scattered across GitHub Actions.

## Service Setup in /mnt/services

For a service to be deployable:

1. **Directory with compose.yml:**
   ```
   /mnt/services/
   └── my-service/
       ├── compose.yml
       ├── Dockerfile (if building custom image)
       ├── artifacts/ (created automatically by deploy)
       └── fnox.toml (if service needs secrets)
   ```

2. **Dockerfile that accepts ARTIFACT arg:**
   ```dockerfile
   FROM scratch
   ARG ARTIFACT
   ADD --unpack ${ARTIFACT} /app/
   CMD ["/app/my-service"]
   ```
   
   Or with Alpine for CA certificates:
   ```dockerfile
   FROM alpine:latest
   RUN apk --no-cache add ca-certificates
   ARG ARTIFACT
   ADD --unpack ${ARTIFACT} /app/
   CMD ["/app/my-service"]
   ```

3. **compose.yml with ARTIFACT arg and fallback:**
   ```yaml
   services:
     app:
       build:
         context: .
         dockerfile: Dockerfile
         args:
           ARTIFACT: ${ARTIFACT:-https://fallback-url.example.com/latest.tgz}
       restart: unless-stopped
       ports:
         - 3000:3000
       environment:
         DATABASE_URL: "${DATABASE_URL}"
   ```
   
   The `args: ARTIFACT: ${ARTIFACT:-<fallback>}` allows both CI (explicit path) and local dev (default URL) usage.

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

**On host (`mise.local.toml`):**
```toml
[env]
OP_SERVICE_ACCOUNT_TOKEN = "ops_eyJ..."
```

**On host:** `gh` CLI authenticated (for `gh run download`)

**GitHub:** Zero secrets required! 🎉
- Tailscale uses OIDC (client ID and audience hardcoded in workflow, not secrets)
- SSH uses Tailscale SSH (no SSH keys to manage)

## Troubleshooting

### Deployment fails with "Permission denied"
- Verify Tailscale SSH is configured correctly for the deploy host
- Check that the `tag:ci` ACL tag has SSH access to the host

### Service fails to start
- SSH into host and check logs: `cd /mnt/services/my-service && docker compose logs`
- Verify secrets are injected: `cd /mnt/services/my-service && fnox env`
- Check if service is using correct ports (no conflicts)

### Artifact download fails
- Verify the `gh` CLI is authenticated on the host: `gh auth status`
- Check that the run ID is valid and the artifact hasn't expired (90 day retention)
- Verify the artifact name matches: `gh run view <run-id> --repo <owner/repo>`
- Test manually: `gh run download <run-id> --repo <owner/repo> --name <artifact-name> --dir ./test/`

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

# Deploy with latest artifact (Dockerfile default fallback)
mise run deploy my-service

# Deploy with a specific local artifact
mise run deploy my-service artifacts/my-service.tgz

# Download and deploy from GitHub
mise run deploy my-service --filename my-service.tgz
```

**Manual Docker Compose:**
You can also work with Docker Compose directly:
```bash
cd /mnt/services/my-service
ARTIFACT=artifacts/latest.tgz docker compose up -d --build --wait
docker compose logs -f
```

**Dockerfile Best Practices:**
- Use `ARG ARTIFACT` (no default in Dockerfile — let compose.yml handle the fallback)
- Use `ADD --unpack` for automatic extraction of tarballs
- Use `FROM scratch` for minimal image size (Go binaries)
- Use `FROM alpine:latest` if you need CA certificates
- The `latest.tgz` copy is maintained by the `deploy` task

**Workflow Concurrency:**
- Deployments use `concurrency: group: deploy-${{ github.repository }}`
- Only one deployment per service runs at a time
- New deployments cancel-in-progress: false (wait for previous to complete)

**Prerequisites on Deploy Host:**
- `mise` installed with tools configured (`gh`, `fnox`)
- `gh` CLI authenticated: `gh auth login`
- `docker` and `docker compose` available
- 1Password service account token in `mise.local.toml`
