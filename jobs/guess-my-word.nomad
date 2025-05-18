variable "artifact" {
  type = string
}

job "guess-my-word" {
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
        command = "guess-my-word"
        args    = ["--port=${NOMAD_PORT_web}"]
      }

      artifact {
        source = var.artifact
      }

      env {
        ADDR     = "0.0.0.0"
        GIN_MODE = "release"
        ORIGIN   = "guessmyword.xyz"
      }

      template {
        data        = <<EOF
            REDIS_HOST="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.host }}{{end}}"
            REDIS_PORT="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.port }}{{end}}"
            REDIS_USER="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.user }}{{end}}"
            REDIS_PASSWORD="{{with secret "credentials/digitalocean/redis"}}{{ .Data.data.password }}{{end}}"
            REDIS_DB=1
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      service {
        name     = "guess-my-word"
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
