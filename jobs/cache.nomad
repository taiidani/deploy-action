variable "tag" {
  type    = string
  default = "8-alpine"
}

variable "insight_tag" {
  type    = string
  default = "2.70"
}

job "cache" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  update {
    auto_revert = true
  }

  group "redis" {
    task "redis" {
      driver = "docker"

      config {
        image = "redis:${var.tag}"
        ports = ["redis"]
        args = ["redis-server", "/config/redis.conf"]

        mount {
          type   = "bind"
          source = "local"
          target = "/config"
        }
      }

      template {
        destination = "local/redis.conf"
        data        = <<EOF
bind 0.0.0.0

port {{ env "NOMAD_PORT_redis" }}

dir /opt/data/redis/
EOF
      }

      volume_mount {
        volume      = "hashistack"
        destination = "/opt/data"
        read_only   = "false"
      }

      resources {
        cpu    = 256
        memory = 1024
      }
    }

    task "insight" {
      driver = "docker"

      config {
        image = "redis/redisinsight:${var.insight_tag}"
        ports = ["ui"]
      }

      env {
        # https://redis.io/docs/latest/operate/redisinsight/configuration/
        RI_REDIS_HOST = "${NOMAD_IP_redis}"
        RI_REDIS_PORT = "${NOMAD_PORT_redis}"
      }

      resources {
        cpu    = 64
        memory = 128
      }
    }

    volume "hashistack" {
      type      = "host"
      source    = "hashistack"
      read_only = "false"
    }

    service {
        name     = "redis"
        provider = "nomad"
        port     = "redis"

        check_restart {
            limit           = 3
            grace           = "15s"
            ignore_warnings = false
        }
    }

    network {
      port "redis" {}
      port "ui" {
        to     = 5540
      }
    }
  }
}
