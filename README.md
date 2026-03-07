# deploy-action

Home lab deployment configurations using Docker Compose.

## What's Here

- **Docker Compose services** - Each service in `<service>/compose.yml`
- **Secrets** - 1Password + fnox injects secrets at runtime
- **Ingress** - Caddy reverse proxy in `caddy/`
- **CI/CD** - GitHub Actions workflows (zero secrets, uses Tailscale OIDC + SSH)
- **Artifacts** - Binaries stored at `<service>/artifacts/` (relative to service dir)

## Quick Start

**Deploy a service:**
```bash
cd <service>
docker compose up -d
```

**Deploy with artifact:**
```bash
cd <service>
mise run deploy <service> /path/to/artifact.tgz
```

## Documentation

- **[SETUP.md](./SETUP.md)** - Initial setup (Tailscale SSH + OIDC)
- **[CLAUDE.md](./CLAUDE.md)** - Main docs for Claude Code assistant
- **[SECRETS.md](./SECRETS.md)** - 1Password + fnox setup

## Service Workflow Example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: go build -o my-service && tar -czf my-service.tgz my-service
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
