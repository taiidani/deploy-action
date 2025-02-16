variable "artifact" {
  type = string
}

job "uptime" {
  datacenters = ["dc1"]
  type        = "batch"
  node_pool   = "home"

  periodic {
    crons            = ["@daily"]
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
          "-exclude=signoz",
          "-exclude=vault",
          "-exclude=containerd",
          "-exclude=1Password",
          "-exclude=cni",
        ]
      }

      env {
        AWS_ENDPOINT = "https://rnd-public.sfo3.digitaloceanspaces.com"
        AWS_REGION   = "us-east-1"
      }

      template {
        data        = <<EOF
            {{with secret "credentials/digitalocean/spaces"}}
            AWS_ACCESS_KEY_ID="{{ .Data.spaces_access_id }}"
            AWS_SECRET_ACCESS_KEY="{{ .Data.spaces_secret_key }}"
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
      role = "nomad-cluster"
    }
  }
}
