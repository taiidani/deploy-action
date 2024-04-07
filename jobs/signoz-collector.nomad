variable "OTELCOL_TAG" {
  type    = string
  default = "0.88.12"
}

job "signoz-collector-home" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "home"

  update {
    canary            = 1
    healthy_deadline  = "4m"
    progress_deadline = "6m"
    auto_promote      = true
    auto_revert       = true
  }

  group "signoz" {
    restart {
      attempts = 10
      delay    = "15s"
    }

    task "otel-collector" {
      driver = "docker"

      config {
        image = "signoz/signoz-otel-collector:${var.OTELCOL_TAG}"
        args = [
          "--config=/etc/otel-collector/otel-collector-config.yaml",
          "--manager-config=/etc/otel-collector/manager-config.yaml",
          "--copy-path=/var/tmp/collector-config.yaml",
          "--feature-gates=-pkg.translator.prometheus.NormalizeName"
        ]
        ports = [
          "otel_collector",
          "jaeger",
        ]

        mount {
          type   = "bind"
          source = "local"
          target = "/etc/otel-collector"
        }
      }

      env {
        OTEL_RESOURCE_ATTRIBUTES        = "host.name=signoz-host,os.type=linux"
        DOCKER_MULTI_NODE_CLUSTER       = "false"
        LOW_CARDINAL_EXCEPTION_GROUPING = "false"
      }

      template {
        data        = file("signoz/otel-collector-config.yaml.tpl")
        destination = "local/otel-collector-config.yaml"
      }

      template {
        data        = file("signoz/otel-collector-opamp-config.yaml.tpl")
        destination = "local/manager-config.yaml"
      }

      service {
        name     = "otel-logs"
        provider = "nomad"
        port     = "otel_collector"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
        }
      }

      service {
        name     = "otel-jaeger"
        provider = "nomad"
        port     = "jaeger"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
        }
      }
    }

    // task "logspout" {
    //   driver = "docker"

    //   config {
    //     image = "gliderlabs/logspout:v3.2.14"
    //     args = [
    //       "syslog+tcp://${NOMAD_ADDR_otel_collector}"
    //     ]

    //     // mount {
    //     //   type   = "bind"
    //     //   source = "/etc/hostname"
    //     //   target = "/etc/host_hostname"
    //     //   readonly = true
    //     // }

    //     // mount {
    //     //   type     = "bind"
    //     //   source   = "/var/run/docker.sock"
    //     //   target   = "/var/run/docker.sock"
    //     //   readonly = false
    //     // }
    //   }

    //   env {
    //     OTEL_RESOURCE_ATTRIBUTES        = "host.name=signoz-host,os.type=linux"
    //     DOCKER_MULTI_NODE_CLUSTER       = "false"
    //     LOW_CARDINAL_EXCEPTION_GROUPING = "false"
    //   }
    // }

    network {
      port "otel_collector" {
        to = 2255
      }
      port "jaeger" {
        to = 14268
      }
    }

    vault {
      policies = ["hcp-root"]
    }
  }
}
