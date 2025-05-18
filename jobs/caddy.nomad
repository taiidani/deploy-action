variable "version" {
  type    = string
  default = "2.10.0"
}

job "caddy" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  update {
    auto_revert = true
  }

  group "ingress" {
    task "proxy" {
      driver = "exec"

      config {
        command = "caddy"
        args    = ["run", "--config", "local/Caddyfile"]
      }

      artifact {
        source = "https://github.com/caddyserver/caddy/releases/download/v${var.version}/caddy_${var.version}_linux_amd64.tar.gz"
      }

      template {
        data        = <<EOF
# Docs: https://caddyserver.com/docs/caddyfile
{
  # Global Options Docs: https://caddyserver.com/docs/caddyfile/options

  storage file_system /data/caddy

  email rnixon@taiidani.com
  # acme_ca https://acme-staging-v02.api.letsencrypt.org/directory

  # log {
  #   output stdout
  # }
}

taiidani.com {
  reverse_proxy {
    {{- range nomadService "homer" }}
    to {{ .Address }}:{{ .Port }}
    {{- end }}
  }
}

www.taiidani.com {
  reverse_proxy {
    {{- range nomadService "homer" }}
    to {{ .Address }}:{{ .Port }}
    {{- end }}
  }
}

middara.taiidani.com {
  reverse_proxy {
    {{- range nomadService "middara" }}
    to {{ .Address }}:{{ .Port }}
    {{- end }}
  }
}

achievements.taiidani.com {
  reverse_proxy {
    {{- range nomadService "achievements" }}
    to {{ .Address }}:{{ .Port }}
    {{- end }}
  }
}

EOF
        destination = "local/Caddyfile"
      }

      volume_mount {
        volume      = "hashistack"
        destination = "/data"
        read_only   = "false"
      }

      resources {
        cpu    = 128
        memory = 256
      }
    }

    # volume "worker" {
    #   type      = "host"
    #   source    = "worker"
    #   read_only = "false"
    # }

    network {
      # mode = "bridge"

      port "http" {
        static = 80
        to     = 80
      }
      port "https" {
        static = 443
        to     = 443
      }
      port "ui" {
        to = 2019
      }
    }

    volume "hashistack" {
      type      = "host"
      source    = "hashistack"
      read_only = "false"
    }
  }
}
