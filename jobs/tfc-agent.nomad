variable "tag" {
  type    = string
  default = "1.15.0"
}

variable "checksum" {
  type    = string
  default = "e4e0e7c8849273a2f203af8eb17c020cf815d61517f041877020e16d77e5b640"
}

job "tfc-agent" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  group "tfc-agent" {
    count = 1

    restart {
      attempts = 70
      delay    = "5s"
      interval = "30m"
    }

    task "tfc-agent" {
      driver = "exec"

      config {
        command = "tfc-agent"
      }

      artifact {
        // https://releases.hashicorp.com/tfc-agent
        source = "https://releases.hashicorp.com/tfc-agent/${var.tag}/tfc-agent_${var.tag}_linux_amd64.zip"

        options {
          checksum = "sha256:${var.checksum}"
        }
      }

      env {
        TFC_AGENT_SINGLE = "true"
        TFC_AGENT_NAME   = "digitalocean-rnd"
      }

      template {
        data = <<EOH
            TFC_AGENT_TOKEN="{{with secret "credentials/tfc-agent"}}{{.Data.data.TFC_AGENT_TOKEN}}{{end}}"
        EOH

        destination = "secrets/config.env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 512
      }
    }

    vault {
      policies = ["hcp-root"]
    }
  }
}
