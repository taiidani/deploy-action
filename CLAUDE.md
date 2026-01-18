# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains deployment tooling for taiidani's home lab. It provides:
1. A GitHub Action (`action.yml`) for standardized Nomad deployments
2. Reusable GitHub workflows for publishing binaries and deploying to Nomad
3. Nomad jobspecs for various services
4. Docker Compose configurations for select services

## Architecture

### GitHub Action Integration

The core GitHub Action (`action.yml`) performs these steps:
1. Creates a `.env` file for environment variables (NOMAD_TOKEN must be set in environment)
2. Uses mise-action to install Nomad CLI (version specified in `.mise.toml`)
3. Validates the jobspec with `nomad job validate -var 'artifact=...' <jobspec>`
4. Deploys with `nomad job run -var 'artifact=...' <jobspec>`

### Reusable Workflows

**`.github/workflows/nomad.yml`** - Main deployment workflow:
- Uses Vault JWT authentication to retrieve secrets
- Connects to Nomad via Tailscale (requires TS_OAUTH_CLIENT_ID and TS_OAUTH_SECRET)
- Nomad cluster address: `http://terra:4646`
- Calls the deploy-action with artifact URL and jobspec path

**`.github/workflows/publish-binary.yml`** - Binary publishing:
- Downloads artifacts from GitHub Actions
- Uploads to DigitalOcean Spaces (S3-compatible) at `rnd-public.sfo3.digitaloceanspaces.com`
- Returns public URL for the artifact
- Requires Vault credentials for DigitalOcean Spaces access

### Nomad Jobspec Patterns

All jobspecs in `jobs/` follow a consistent pattern:

**Variable Declaration:**
```hcl
variable "artifact" {
  type = string
}
```

**Common Job Configuration:**
- `datacenters = ["dc1"]`
- `type = "service"`
- `node_pool` is "home"
- Update strategy includes canary deployment with auto-promote and auto-revert

**Artifact Fetching:**
```hcl
artifact {
  source = var.artifact
}
```

**Service Discovery:**
Services register with Nomad's service catalog using:
```hcl
service {
  name     = "service-name"
  provider = "nomad"
  port     = "web"
}
```

**Vault Integration:**
Jobspecs use Vault templates to inject secrets:
```hcl
vault {
  role = "nomad-cluster"
}

template {
  data        = <<EOF
KEY="{{with secret "path"}}{{ .Data.data.KEY }}{{end}}"
EOF
  destination = "${NOMAD_SECRETS_DIR}/secrets.env"
  env         = true
}
```

**Service Discovery in Templates:**
Services discover each other using Nomad's template syntax:
```hcl
{{range nomadService "service-name"}}{{.Address}}:{{.Port}}{{end}}
```

### Infrastructure Layout

**One Node Pool:**
1. `home` - Home lab nodes (runs Caddy ingress, most services)

**Ingress Patterns:**
- `jobs/caddy.nomad` - HTTP ingress for home node pool, uses Caddyfile template with reverse_proxy blocks
- `jobs/ingress.nomad` - Traefik ingress for digitalocean node pool, uses dynamic configuration from Nomad provider

**Docker Compose Services:**
Located in subdirectories, these run outside Nomad:
- `lil-dumpster/` - Discord bot with Redis
- `beszel/` - Monitoring service
- `tfc-agent/` - Terraform Cloud agents (scaled to 2 instances)

## Development Commands

### Testing Jobspecs Locally

Validate a jobspec:
```bash
nomad job validate -var 'artifact=https://example.com/binary' jobs/<jobspec>.nomad
```

Plan a deployment (dry-run):
```bash
nomad job plan -var 'artifact=https://example.com/binary' jobs/<jobspec>.nomad
```

Deploy a job:
```bash
nomad job run -var 'artifact=https://example.com/binary' jobs/<jobspec>.nomad
```

### Environment Setup

Set NOMAD_TOKEN in `.env` file (mise will load it automatically):
```bash
echo 'NOMAD_TOKEN=your-token-here' > .env
```

Mise will install the correct Nomad version automatically when you run nomad commands.

### Working with Docker Compose Services

Start a service:
```bash
cd <service-directory>
docker compose up -d
```

View logs:
```bash
docker compose logs -f
```

Stop a service:
```bash
docker compose down
```

## Key Patterns

### Adding a New Service

1. Create a new jobspec in `jobs/<service-name>.nomad`
2. Follow the standard pattern: include `variable "artifact"`, use exec or docker driver, register service with Nomad provider
3. If ingress is needed, add a reverse_proxy block to `jobs/caddy.nomad`
4. Services should set `GOMEMLIMIT` for Go applications to prevent OOM kills
5. Use canary deployments with auto-promote and auto-revert for safer deployments

### Service Dependencies

Services find dependencies via Nomad service discovery in templates:
```hcl
REDIS_HOST="{{range nomadService "redis"}}{{.Address}}{{end}}"
REDIS_PORT="{{range nomadService "redis"}}{{.Port}}{{end}}"
```

### Volume Mounts

Persistent storage uses host volumes:
```hcl
volume_mount {
  volume      = "hashistack"
  destination = "/data"
  read_only   = "false"
}

volume "hashistack" {
  type      = "host"
  source    = "hashistack"
  read_only = "false"
}
```

## Vault Integration

All GitHub workflows authenticate to Vault using JWT:
- Vault URL: `https://rnd.vault.0846e66f-a975-4a88-9e46-6dc6267e9b73.aws.hashicorp.cloud:8200`
- Role: `github-role`
- Path: `github`
- Namespace: `admin`

Secrets are stored at:
- `nomad/creds/deployer` - Nomad token
- `credentials/data/github` - Tailscale OAuth credentials
- `credentials/data/digitalocean/spaces` - S3 credentials
- `deploy/<service-name>` - Service-specific secrets
