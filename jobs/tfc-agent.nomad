variable "tag" {
  type    = string
  default = "1.17.5"
}

variable "checksum" {
  type    = string
  default = "5f7b7c6ed22b7d85b3e28261edbb2eb1f1aad0bfe890531b8e6f3c2b69a7f44d"
}

job "tfc-agent" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  group "tfc-agent" {
    count = 2

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
