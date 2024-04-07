variable "OTELCOL_TAG" {
  type    = string
  default = "0.88.12"
}

job "signoz" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  update {
    healthy_deadline  = "4m"
    progress_deadline = "6m"
    auto_revert       = true

    // Signoz will crash if another instance is using the same data directory
    // canary            = 1
    // auto_promote      = true
  }

  group "signoz" {
    restart {
      attempts = 10
      delay    = "15s"
    }

    task "zookeeper" {
      driver = "docker"

      config {
        image = "bitnami/zookeeper:3.7.1"
        ports = ["zookeeper"]
      }

      env {
        ZOO_SERVER_ID          = "1"
        ALLOW_ANONYMOUS_LOGIN  = "yes"
        ZOO_AUTOPURGE_INTERVAL = "1"
      }

      service {
        name     = "signoz-zookeeper"
        provider = "nomad"
        port     = "zookeeper"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
        }
      }
    }

    task "clickhouse" {
      driver = "docker"

      config {
        image = "clickhouse/clickhouse-server:24.1.2-alpine"
        ports = ["clickhouse_http", "clickhouse_tcp"]
        tty   = "true"

        ulimit {
          nproc  = "65535"
          nofile = "262144:262144"
        }

        mount {
          type   = "bind"
          source = "local"
          target = "/etc/clickhouse-server"
        }
      }

      volume_mount {
        volume      = "hashistack"
        destination = "/data"
        read_only   = "false"
      }

      template {
        data        = file("signoz/clickhouse-config.xml")
        destination = "local/config.xml"
      }

      template {
        data        = file("signoz/clickhouse-users.xml")
        destination = "local/users.xml"
      }

      template {
        data        = file("signoz/clickhouse-cluster.xml")
        destination = "local/config.d/cluster.xml"
      }

      template {
        data        = file("signoz/custom-function.xml")
        destination = "local/custom-function.xml"
      }

      service {
        name     = "signoz-clickhouse-http"
        provider = "nomad"
        port     = "clickhouse_http"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
        }
      }

      service {
        name     = "signoz-clickhouse-tcp"
        provider = "nomad"
        port     = "clickhouse_tcp"

        check {
          type     = "tcp"
          port     = "clickhouse_tcp"
          interval = "10s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 200
        memory = 2048
      }
    }

    task "alertmanager" {
      driver = "docker"

      config {
        image = "signoz/alertmanager:0.23.5"
        args = [
          "--queryService.url=http://${NOMAD_ADDR_query_service}",
          "--storage.path=/data"
        ]
        ports = ["alertmanager"]
      }
    }

    task "query-service" {
      driver = "docker"

      config {
        image = "signoz/query-service:0.42.0"
        args = [
          "-config=/etc/query-service/prometheus.yml"
        ]
        ports = ["query_service", "query_service_api", "query_service_ws"]

        mount {
          type   = "bind"
          source = "local"
          target = "/etc/query-service"
        }
      }

      volume_mount {
        volume      = "hashistack"
        destination = "/data"
        read_only   = "false"
      }

      env {
        ClickHouseUrl           = "tcp://${NOMAD_ADDR_clickhouse_tcp}"
        ALERTMANAGER_API_PREFIX = "http://${NOMAD_ADDR_alertmanager}/api/"
        SIGNOZ_LOCAL_DB_PATH    = "/data/signoz/query-service/signoz.db" # "/var/lib/signoz/signoz.db"
        DASHBOARDS_PATH         = "/etc/query-service/dashboards"        # "/root/config/dashboards"
        STORAGE                 = "clickhouse"
        GODEBUG                 = "netdns=go"
        TELEMETRY_ENABLED       = "true"
        DEPLOYMENT_TYPE         = "docker-standalone-amd"
      }

      template {
        data        = file("signoz/prometheus.yml.tpl")
        destination = "local/prometheus.yml"
      }

      service {
        name     = "signoz-query-service-private"
        provider = "nomad"
        port     = "query_service"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
        }
      }

      service {
        name     = "signoz-query-service-api"
        provider = "nomad"
        port     = "query_service_api"

        check {
          type     = "http"
          method   = "GET"
          path     = "/api/v1/health"
          interval = "10s"
          timeout  = "5s"
        }
      }

      service {
        name     = "signoz-query-service-ws"
        provider = "nomad"
        port     = "query_service_ws"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
        }
      }
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "signoz/frontend:0.39.0"
        ports = ["http"]

        mount {
          type   = "bind"
          source = "local"
          target = "/etc/nginx/conf.d"
        }
      }

      template {
        data        = file("signoz/nginx-config.conf")
        destination = "local/default.conf"
      }

      service {
        name     = "signoz"
        provider = "nomad"
        port     = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.signoz.rule=Host(`signoz.taiidani.com`)",
          "traefik.http.routers.signoz.middlewares=signoz@nomad",
          "traefik.http.routers.signozsecure.rule=Host(`signoz.taiidani.com`)",
          "traefik.http.routers.signozsecure.tls=true",
          "traefik.http.routers.signozsecure.tls.certresolver=le",
          "traefik.http.routers.signozsecure.middlewares=signoz@nomad",
          "traefik.http.middlewares.signoz.redirectscheme.permanent=true",
          "traefik.http.middlewares.signoz.redirectscheme.scheme=https",
        ]

        check {
          method   = "GET"
          type     = "http"
          path     = "/"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    task "otel-collector-migrator" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      config {
        image = "signoz/signoz-schema-migrator:${var.OTELCOL_TAG}"
        args = [
          "--dsn=tcp://${NOMAD_ADDR_clickhouse_tcp}"
        ]
      }
    }

    volume "hashistack" {
      type      = "host"
      source    = "hashistack"
      read_only = "false"
    }

    network {
      port "http" {
        to = 3301
      }
      port "alertmanager" {
        to = 9093
      }
      port "clickhouse_tcp" {
        to = 9000
      }
      port "clickhouse_http" {
        to = 8123
      }
      port "query_service" {
        to = 8085
      }
      port "query_service_ws" {
        to = 4320
      }
      port "query_service_api" {
        to = 8080
      }
      port "zookeeper" {
        to = 2181
      }
    }

    vault {
      policies = ["hcp-root"]
    }
  }
}
