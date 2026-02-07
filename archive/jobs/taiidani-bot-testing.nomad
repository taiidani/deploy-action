variable "tag" {
  type    = string
  default = "dev"
}

job "taiidani-bot-testing" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "digitalocean"

  update {
    auto_revert = true
  }

  group "taiidani-bot-testing" {
    task "app" {
      driver = "docker"

      config {
        image = "ghcr.io/taiidani/no-time-to-explain:${var.tag}"
      }

      env {
        CMD_TZ = "EDT"
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{range nomadService "redis"}}{{.Address}}{{end}}"
            REDIS_PORT="{{range nomadService "redis"}}{{.Port}}{{end}}"
            DISCORD_TOKEN="{{with secret "deploy/taiidani-bot-testing"}}{{ .Data.data.DISCORD_TOKEN }}{{end}}"
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
