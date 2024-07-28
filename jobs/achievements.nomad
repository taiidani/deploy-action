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
        command = "achievements"
      }

      artifact {
        source = var.artifact
      }

      template {
        data        = <<EOF
            STEAM_KEY="{{with secret "deploy/achievements"}}{{ .Data.data.STEAM_KEY }}{{end}}"
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
        cpu    = 50
        memory = 128
      }
    }

    network {
      port "web" {
        to = 80
      }
    }

    vault {
      policies = ["digitalocean-app"]
    }
  }
}