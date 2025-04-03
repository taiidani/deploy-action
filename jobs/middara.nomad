variable "artifact" {
  type = string
}

job "middara" {
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

  reschedule {
    attempts  = 1
    interval  = "1m"
    delay     = "15s"
    unlimited = false
  }

  group "app" {
    count = 1

    task "app" {
      driver = "exec"

      config {
        command = "app"
      }

      artifact {
        source = var.artifact
      }

      env {
        PORT       = "${NOMAD_PORT_web}"
        PUBLIC_URL = "https://middara.taiidani.com"
        GOMEMLIMIT = "60MiB"
        DB_TYPE    = "postgres"
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.host }}{{end}}"
            REDIS_PORT="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.port }}{{end}}"
            REDIS_USER="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.user }}{{end}}"
            REDIS_PASSWORD="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.password }}{{end}}"
            REDIS_DB=3
            DATABASE_URL="{{with secret "deploy/middara"}}{{ .Data.data.DATABASE_URL }}{{end}}"
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      service {
        name     = "middara"
        provider = "nomad"
        port     = "web"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.middara.rule=Host(`middara.taiidani.com`)",
          "traefik.http.routers.middara.middlewares=middara@nomad",
          "traefik.http.routers.middarasecure.rule=Host(`middara.taiidani.com`)",
          "traefik.http.routers.middarasecure.tls=true",
          "traefik.http.routers.middarasecure.tls.certresolver=le",
          "traefik.http.routers.middarasecure.middlewares=middara@nomad",
          "traefik.http.middlewares.middara.redirectscheme.permanent=true",
          "traefik.http.middlewares.middara.redirectscheme.scheme=https",
        ]

        check_restart {
          limit           = 3
          grace           = "15s"
          ignore_warnings = false
        }
      }

      resources {
        cpu    = 512
        memory = 128
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
