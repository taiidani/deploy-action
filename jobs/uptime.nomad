variable "artifact" {
  type    = string
  default = "https://github.com/taiidani/uptime/releases/download/v0.3/uptime_0.3_Linux_x86_64.tar.gz"
}

job "uptime" {
  datacenters = ["dc1"]
  type        = "sysbatch"
  node_pool   = "home"

  periodic {
    cron             = "@daily"
    prohibit_overlap = true
  }

  group "uptime" {
    task "backup" {
      driver = "exec"

      artifact {
        source      = "${var.artifact}"
        destination = "local/uptime"
      }

      config {
        command = "uptime/uptime"
        args = [
          "-folder=/data",
          "-exclude=nomad",
          "-exclude=consul",
          "-exclude=vault",
          "-exclude=containerd",
          "-exclude=1Password",
          "-exclude=cni",
        ]
      }

      template {
        data        = <<EOF
            {{with secret "aws/creds/uptime"}}
            AWS_ACCESS_KEY_ID="{{ .Data.access_key }}"
            AWS_SECRET_ACCESS_KEY="{{ .Data.secret_key }}"
            {{end}}

        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
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

    volume "hashistack" {
      type      = "host"
      source    = "hashistack"
      read_only = "false"
    }

    vault {
      policies = ["hcp-root"]
    }
  }
}
