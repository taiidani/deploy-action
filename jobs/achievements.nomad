variable "artifact" {
  type = string
}

job "achievements" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

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
            REDIS_HOST="{{range nomadService "redis"}}{{.Address}}{{end}}"
            REDIS_PORT="{{range nomadService "redis"}}{{.Port}}{{end}}"
            REDIS_DB=2
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      service {
        name     = "achievements"
        provider = "nomad"
        port     = "web"

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
