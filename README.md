# deploy-action

Deployment configurations for taiidani's home lab.

This repository contains Docker Compose configurations and deployment tooling for services running on taiidani's home lab infrastructure.

## Quick Start

See [CLAUDE.md](./CLAUDE.md) for comprehensive documentation on:
- Service architecture and patterns
- Secrets management with Vault
- Development and deployment workflows
- Adding new services

## Key Components

- **Docker Compose services** - Each service in its own directory with `compose.yml`
- **Vault Agent integration** - Secrets rendered from templates to `.env` files
- **Caddy ingress** - HTTP reverse proxy with automatic HTTPS
- **Legacy workflows** - Binary publishing to DigitalOcean Spaces (still active)

## Migration Note

This repository was previously used for Nomad orchestration. All Nomad-related files have been archived to `archive/` for historical reference. The infrastructure now uses Docker Compose exclusively.
