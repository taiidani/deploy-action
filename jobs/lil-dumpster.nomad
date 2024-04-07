variable "tag" {
  type    = string
  default = "latest"
}

job "lil-dumpster" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  update {
    auto_revert = true
  }

  group "lil-dumpster" {
    task "app" {
      driver = "docker"

      config {
        image = "ghcr.io/team-dumpster-fire/lil-dumpster:${var.tag}"
      }

      env {
        REDIS_HOST = "${NOMAD_IP_redis}"
        REDIS_PORT = "${NOMAD_PORT_redis}"
      }

      template {
        data        = <<EOF
            DISCORD_TOKEN="{{with secret "lil-dumpster/kv/discord"}}{{ .Data.data.token }}{{end}}"
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    volume "hashistack" {
      type      = "host"
      source    = "hashistack"
      read_only = "false"
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:6"
        args = [
          "redis-server",
          "--dir", "/data/lil-dumpster",
          "--port", "${NOMAD_PORT_redis}",
          "--bind", "0.0.0.0"
        ]
        ports = ["redis"]
      }

      volume_mount {
        volume      = "hashistack"
        destination = "/data"
        read_only   = "false"
      }

      resources {
        cpu    = 25
        memory = 32
      }
    }

    network {
      port "redis" {}
    }

    vault {
      policies = ["hcp-root"]
    }
  }
}
