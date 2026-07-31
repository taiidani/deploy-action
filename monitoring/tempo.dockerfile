FROM grafana/tempo:3.0.2

COPY ./tempo/tempo-config.yml /etc/tempo/tempo-config.yml
