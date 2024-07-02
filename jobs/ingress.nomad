variable "tag" {
  type    = string
  default = "v3.1"
}

job "ingress" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "digitalocean"

  update {
    auto_revert = true
  }

  group "traefik" {
    task "agent" {
      driver = "docker"

      config {
        image = "traefik:${var.tag}"
        ports = ["http", "https", "ui"]

        mount {
          type   = "bind"
          source = "local"
          target = "/etc/traefik"
        }
      }

      volume_mount {
        volume      = "worker"
        destination = "/data"
        read_only   = "false"
      }

      template {
        data        = <<EOF
[ping]

[accessLog]
# format = "json"

[tracing]
[tracing.otlp.http]
endpoint = "http://{{ env "attr.driver.docker.bridge_ip" }}:4318/v1/traces"

[entryPoints]
[entryPoints.web]
address = ":80"
[entryPoints.web.proxyProtocol]
trustedIPs = ["127.0.0.1/32", "10.0.0.0/8"]

[entryPoints.websecure]
address = ":443"
[entryPoints.websecure.proxyProtocol]
trustedIPs = ["127.0.0.1/32", "10.0.0.0/8"]

[certificatesResolvers.le.acme]
email = "rnixon+traefik@taiidani.com"
storage = "/data/traefik/acme/le.json"
# caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"

[certificatesResolvers.le.acme.httpChallenge]
entryPoint = "web"

[api]
dashboard = true
insecure = true

# Enable Nomad configuration backend.
[providers.nomad]
exposedByDefault = false

[providers.nomad.endpoint]
address = "http://{{ env "attr.driver.docker.bridge_ip" }}:4646"
EOF
        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 25
        memory = 64
      }
    }

    volume "worker" {
      type      = "host"
      source    = "worker"
      read_only = "false"
    }

    network {
      mode = "bridge"
      port "http" {
        static = 80
        to     = 80
      }
      port "https" {
        static = 443
        to     = 443
      }
      port "ui" {
        static = 8080
        to     = 8080
      }
    }
  }

  // // Enable when troubleshooting
  // group "backend" {
  //   network {
  //     mode = "bridge"
  //   }

  //   service {
  //     name = "whoami"
  //     provider = "nomad"
  //     port = 80
  //     tags = [
  //       "traefik.enable=true",
  //       "traefik.consulcatalog.connect=true",
  //       "traefik.http.routers.whoami.rule=Host(`whoami.taiidani.com`)"
  //     ]
  //   }

  //   # Note: For increased security the service should only listen on localhost
  //   # Otherwise it could be reachable from the outside world without going through connect
  //   task "whoami" {
  //     driver = "docker"
  //     config {
  //       image = "containous/whoami"
  //     }
  //   }
  // }
}
