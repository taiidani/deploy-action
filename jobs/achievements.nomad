variable "artifact" {
  type = string
}

job "achievements" {
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
        PUBLIC_URL = "https://achievements.taiidani.com"
        GOMEMLIMIT = "120MiB"
      }

      template {
        data        = <<EOF
            STEAM_KEY="{{with secret "deploy/achievements"}}{{ .Data.data.STEAM_KEY }}{{end}}"
            REDIS_HOST="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.host }}{{end}}"
            REDIS_PORT="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.port }}{{end}}"
            REDIS_USER="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.user }}{{end}}"
            REDIS_PASSWORD="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.password }}{{end}}"
            REDIS_DB=2
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      service {
        name     = "achievements"
        provider = "nomad"
        port     = "web"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.achievements.rule=Host(`achievements.taiidani.com`)",
          "traefik.http.routers.achievements.middlewares=achievements@nomad",
          "traefik.http.routers.achievementssecure.rule=Host(`achievements.taiidani.com`)",
          "traefik.http.routers.achievementssecure.tls=true",
          "traefik.http.routers.achievementssecure.tls.certresolver=le",
          "traefik.http.routers.achievementssecure.middlewares=achievements@nomad",
          "traefik.http.middlewares.achievements.redirectscheme.permanent=true",
          "traefik.http.middlewares.achievements.redirectscheme.scheme=https",
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
      policies = ["digitalocean-app"]
    }
  }
}
