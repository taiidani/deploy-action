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
        REDIS_HOST = "{{range nomadService "redis"}}{{.Address}}{{end}}"
        REDIS_PORT = "{{range nomadService "redis"}}{{.Port}}{{end}}"
      }

      template {
        data        = <<EOF
            DISCORD_TOKEN="{{with secret "deploy/lil-dumpster"}}{{ .Data.data.DISCORD_TOKEN }}{{end}}"
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

    vault {
      role = "nomad-cluster"
    }
  }
}
