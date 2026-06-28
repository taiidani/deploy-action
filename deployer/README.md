# deployer

A lightweight HTTP server that receives GitHub App webhook events and triggers `mise run deploy` on the host. It replaces the Tailscale SSH + GitHub Actions reusable workflow approach with a persistent webhook listener.

## How It Works

```
Service Repo Push → GitHub Actions Build → Workflow Completes
    → GitHub App sends webhook → deployer :3201
    → mise run deploy <service> --filename <service>.tgz --run-id <id>
```

The server listens for `workflow_run` events and deploys when:

1. Action is `completed`
2. Conclusion is `success`
3. Branch is the repository's default branch

The repository name maps directly to the service directory (e.g. `taiidani/groceries` → `groceries`).

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3201` | HTTP listen port |
| `DEPLOY_PATH` | `/mnt/services` | Base directory containing service subdirectories |
| `GITHUB_WEBHOOK_SECRET` | _(empty)_ | HMAC-SHA256 secret for webhook signature validation |

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check, returns `{"status":"ok"}` |
| `POST` | `/webhook` | GitHub webhook receiver |

## Building

```bash
cd deployer
go build -o deployer .
```

## Running

```bash
export GITHUB_WEBHOOK_SECRET="your-secret"
export DEPLOY_PATH="/mnt/services"
./deployer
```

## Deployment (systemd)

Install the binary and unit file:

```bash
# Build
go build -o deployer .

# Install binary
sudo cp deployer /usr/local/bin/deployer

# Create service user
sudo useradd --system --no-create-home deployer

# Install environment file with secrets
sudo mkdir -p /etc/deployer
echo 'GITHUB_WEBHOOK_SECRET=your-secret-here' | sudo tee /etc/deployer/env
sudo chmod 600 /etc/deployer/env

# Install and start unit
sudo cp deployer.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now deployer
```

## Ingress

Traffic arrives via Caddy reverse proxy at `deploy.taiidani.com`:

```
deploy.taiidani.com {
  reverse_proxy {
    to 192.168.102.80:3201
  }
}
```

## GitHub App Setup

1. Create a GitHub App at https://github.com/settings/apps
2. Set the webhook URL to `https://deploy.taiidani.com/webhook`
3. Generate and set a webhook secret (same value as `GITHUB_WEBHOOK_SECRET`)
4. Subscribe to **Workflow run** events
5. Install the app on your `taiidani` repositories

## Testing

```bash
cd deployer
go test ./...
```
