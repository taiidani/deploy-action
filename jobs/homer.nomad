variable "tag" {
  type    = string
  default = "v23.10.1"
}

job "homer" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  group "homer" {
    update {
      auto_revert = true
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "homer" {
      driver = "docker"

      config {
        image = "b4bz/homer:${var.tag}"
        ports = ["http"]

        mount {
          type   = "bind"
          source = "local"
          target = "/www/assets"
        }
      }

      env {
        PORT = "${NOMAD_PORT_http}"
      }

      template {
        data        = file("homer-config.yml")
        destination = "local/config.yml"
      }

      resources {
        cpu    = 25
        memory = 32
      }
    }

    service {
      name     = "homer"
      provider = "nomad"
      port     = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.homer.rule=Host(`taiidani.com`, `www.taiidani.com`)",
        "traefik.http.routers.homer.middlewares=homer@nomad",
        "traefik.http.routers.homersecure.rule=Host(`taiidani.com`, `www.taiidani.com`)",
        "traefik.http.routers.homersecure.tls=true",
        "traefik.http.routers.homersecure.tls.certresolver=le",
        "traefik.http.routers.homersecure.middlewares=homer@nomad",
        "traefik.http.middlewares.homer.redirectscheme.permanent=true",
        "traefik.http.middlewares.homer.redirectscheme.scheme=https",
      ]

      // check {
      //   method   = "GET"
      //   type     = "http"
      //   path     = "/"
      //   port     = "http"
      //   interval = "10s"
      //   timeout  = "2s"
      // }
    }

    network {
      port "http" {}
    }
  }
}
