variable "artifact" {
  type = string
}

job "no-time-to-explain-refresh" {
  datacenters = ["dc1"]
  type        = "batch"
  node_pool   = "home"

  periodic {
    # Every 10 minutes
    crons            = ["*/10 * * * * *"]
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

        # no-time-to-explain: https://discord.com/channels/372591705754566656/1341142254902837380
        # bot-stuff: https://discord.com/channels/570720951373922304/651857324658524181
        # destiny-tweets: https://discord.com/channels/570720951373922304/715987686678200320
        BLUESKY_FEED_CHANNEL_ID = "715987686678200320"
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{range nomadService "redis"}}{{.Address}}{{end}}"
            REDIS_PORT="{{range nomadService "redis"}}{{.Port}}{{end}}"
            DATABASE_URL="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DATABASE_URL }}{{end}}"
            BUNGIE_API_KEY="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.BUNGIE_API_KEY }}{{end}}"
            DISCORD_TOKEN="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DISCORD_TOKEN }}{{end}}"
            DISCORD_CLIENT_ID="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DISCORD_CLIENT_ID }}{{end}}"
            DISCORD_CLIENT_SECRET="{{with secret "deploy/no-time-to-explain"}}{{ .Data.data.DISCORD_CLIENT_SECRET }}{{end}}"
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
