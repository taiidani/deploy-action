variable "artifact" {
  type = string
}

job "middara" {
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
        PUBLIC_URL = "https://middara.taiidani.com"
        GOMEMLIMIT = "60MiB"
        DB_TYPE    = "postgres"
        REDIS_HOST = "${NOMAD_IP_redis}"
        REDIS_PORT = "${NOMAD_PORT_redis}"
      }

      template {
        data        = <<EOF
            DATABASE_URL="{{with secret "deploy/middara"}}{{ .Data.data.DATABASE_URL }}{{end}}"
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      service {
        name     = "middara"
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

    task "redis" {
      driver = "docker"

      config {
        image = "redis:8"
        args = [
          "redis-server",
          "--port", "${NOMAD_PORT_redis}",
          "--bind", "0.0.0.0"
        ]
        ports = ["redis"]
      }

      resources {
        cpu    = 25
        memory = 32
      }
    }

    network {
      port "web" {}
      port "redis" {}
    }

    vault {
      role = "nomad-cluster"
    }
  }
}
