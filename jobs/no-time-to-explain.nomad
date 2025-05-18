variable "artifact" {
  type = string
}

job "no-time-to-explain" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  update {
    auto_revert = true
  }

  group "no-time-to-explain" {
    task "app" {
      driver = "exec"

      config {
        command = "no-time-to-explain"
      }

      artifact {
        source = var.artifact
      }

      env {
        SENTRY_ENVIRONMENT = "prod"
        SENTRY_DSN         = "https://7fd4c058e6685608ada24d63281f6d59@o55858.ingest.us.sentry.io/4507279390539776"
        CMD_TZ             = "EDT"
        PORT               = "${NOMAD_PORT_web}"
        URL                = "https://no-time-to-explain.taiidani.com"
        DB_TYPE            = "postgres"
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.host }}{{end}}"
            REDIS_PORT="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.port }}{{end}}"
            REDIS_USER="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.user }}{{end}}"
            REDIS_PASSWORD="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.password }}{{end}}"
            DISCORD_TOKEN="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DISCORD_TOKEN }}{{end}}"
            DISCORD_CLIENT_ID="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DISCORD_CLIENT_ID }}{{end}}"
            DISCORD_CLIENT_SECRET="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DISCORD_CLIENT_SECRET }}{{end}}"
            DATABASE_URL="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DATABASE_URL }}{{end}}"
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      service {
        name     = "no-time-to-explain"
        provider = "nomad"
        port     = "web"

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
