FROM prom/prometheus:v3.13.0

COPY ./prometheus/prometheus.yml /etc/prometheus/prometheus.yml
