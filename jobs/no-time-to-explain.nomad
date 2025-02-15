variable "artifact" {
  type = string
}

job "no-time-to-explain" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "digitalocean"

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
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.private_host }}{{end}}"
            REDIS_PORT="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.port }}{{end}}"
            REDIS_USER="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.user }}{{end}}"
            REDIS_PASSWORD="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.password }}{{end}}"
            DISCORD_TOKEN="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DISCORD_TOKEN }}{{end}}"
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    vault {
      role = "nomad-cluster"
    }
  }
}
