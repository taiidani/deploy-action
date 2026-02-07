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

groceries.taiidani.com {
  reverse_proxy {
    to 192.168.102.5:3501
  }
}

no-time-to-explain.taiidani.com {
  reverse_proxy {
    to 192.168.102.5:3502
  }
}

obsidian.taiidani.com {
  encode zstd gzip
  reverse_proxy https://publish.obsidian.md {
    header_up Host {upstream_hostport}
  }
  rewrite * /serve?url=obsidian.taiidani.com{path}
}

guess.taiidani.com {
  redir https://guessmyword.xyz{uri} permanent
}

guessmyword.xyz {
  reverse_proxy {
    to 192.168.102.5:3500
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

    service {
        name     = "caddy"
        provider = "nomad"
        port     = "http"

        check_restart {
            limit           = 3
            grace           = "15s"
            ignore_warnings = false
        }
    }

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
