variable "artifact" {
  type = string
}

job "no-time-to-explain" {
  datacenters = ["dc1"]
  type        = "batch"
  node_pool   = "digitalocean"

  periodic {
    crons            = ["@hourly"]
    prohibit_overlap = true
  }

  group "no-time-to-explain" {
    task "app" {
      driver = "exec"

      config {
        command = "no-time-to-explain"
        args    = ["refresh"]
      }

      artifact {
        source = var.artifact
      }

      env {
        SENTRY_ENVIRONMENT = "prod"
        SENTRY_DSN         = "https://7fd4c058e6685608ada24d63281f6d59@o55858.ingest.us.sentry.io/4507279390539776"
        DB_TYPE            = "postgres"
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.private_host }}{{end}}"
            REDIS_PORT="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.port }}{{end}}"
            REDIS_USER="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.user }}{{end}}"
            REDIS_PASSWORD="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.password }}{{end}}"
            DATABASE_URL="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DATABASE_URL }}{{end}}"
            BUNGIE_API_KEY="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.BUNGIE_API_KEY }}{{end}}"
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      resources {
        cpu    = 50
        memory = 128
      }
    }

    vault {
      role = "nomad-cluster"
    }
  }
}
