FROM grafana/loki:3.7.3

COPY ./loki/loki-config.yml /etc/loki/loki-config.yml
