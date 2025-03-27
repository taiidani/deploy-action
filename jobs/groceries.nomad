variable "artifact" {
  type = string
}

job "groceries" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "digitalocean"

  update {
    canary            = 1
    healthy_deadline  = "2m"
    progress_deadline = "3m"
    auto_promote      = true
    auto_revert       = true
  }

  group "groceries" {
    count = 1

    task "app" {
      driver = "exec"

      config {
        command = "groceries"
      }

      artifact {
        source = var.artifact
      }

      env {
        SENTRY_ENVIRONMENT = "prod"
        SENTRY_DSN         = "https://b7c94726c8e39af642f012583a6be274@o55858.ingest.us.sentry.io/4508903750434816"
        PORT               = "${NOMAD_PORT_web}"
        URL                = "https://groceries.taiidani.com"
        LOG_LEVEL          = "info"
        DB_TYPE            = "postgres"
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.private_host }}{{end}}"
            REDIS_PORT="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.port }}{{end}}"
            REDIS_USER="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.user }}{{end}}"
            REDIS_PASSWORD="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.password }}{{end}}"
            DATABASE_URL="{{with secret "deploy/groceries"}}{{ .Data.data.DATABASE_URL }}{{end}}"
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      service {
        name     = "groceries"
        provider = "nomad"
        port     = "web"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.groceries.rule=Host(`groceries.taiidani.com`)",
          "traefik.http.routers.groceries.middlewares=groceries@nomad",
          "traefik.http.routers.groceriessecure.rule=Host(`groceries.taiidani.com`)",
          "traefik.http.routers.groceriessecure.tls=true",
          "traefik.http.routers.groceriessecure.tls.certresolver=le",
          "traefik.http.routers.groceriessecure.middlewares=groceries@nomad",
          "traefik.http.middlewares.groceries.redirectscheme.permanent=true",
          "traefik.http.middlewares.groceries.redirectscheme.scheme=https",
        ]

        check_restart {
          limit           = 3
          grace           = "15s"
          ignore_warnings = false
        }
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    network {
      port "web" {}
    }

    vault {
      role = "nomad-cluster"
    }
  }
}
