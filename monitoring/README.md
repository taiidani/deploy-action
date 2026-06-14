# Monitoring

Observability stack for the home lab, centered on Grafana.

| Component | Role | Datadog equivalent |
| --- | --- | --- |
| Grafana | Dashboards + querying (port 3900, fronted by Caddy at `taiidani.com`) | Dashboards |
| Prometheus | Metrics storage + scraping (port 9095, 30-day retention) | Metrics backend |
| node_exporter | Per-host metrics, installed on each host (port 9100) | Agent (infra metrics) |
| cAdvisor | Per-container metrics, one container per host (port 8081, see `../cadvisor/`) | Docker integration |

Grafana and Prometheus run together in this stack so they share a Compose
network — Grafana reaches Prometheus at `http://prometheus:9090` by name. The
Prometheus datasource is provisioned as code in
`provisioning/datasources/datasources.yml`.

## Deploy the central stack

```bash
cd monitoring
docker compose up -d
```

Grafana state lives in `./data/grafana` (migrated from the old `grafana/`
service, owned by UID 472 — leave the ownership as-is). Prometheus data lives in
`./data/prometheus`. Both are gitignored.

## Install host metrics (node_exporter)

On every Fedora host you want host-level metrics from (`terra`, `obsidian`):

```bash
sudo dnf install golang-github-prometheus-node-exporter
sudo systemctl enable --now node_exporter
sudo firewall-cmd --add-port=9100/tcp --permanent && sudo firewall-cmd --reload
```

That package ships the binary and a systemd unit — no config required. It listens
on `:9100`.

## Install container metrics (cAdvisor)

On every host that runs Docker containers, deploy the adjacent `cadvisor/` stack:

```bash
cd ../cadvisor
docker compose up -d
```

cAdvisor listens on host port `8081`.

## Add a new host

1. Install node_exporter (above) and deploy the `cadvisor/` stack on the host.
2. Add the host's LAN IP to both the `node` and `cadvisor` jobs in
   `prometheus/prometheus.yml`.
3. Reload Prometheus: `docker compose exec prometheus kill -HUP 1`
   (or `docker compose restart prometheus`).

## First dashboard

Once Prometheus is scraping, import the community **Node Exporter Full**
dashboard (ID `1860`) in Grafana via *Dashboards → New → Import*. It gives a
rich host overview out of the box.

## Next: logs with Loki

Loki is stubbed out as commented blocks in `compose.yml` and
`provisioning/datasources/datasources.yml`. When ready, uncomment both and add a
log shipper (Promtail or Grafana Alloy) on each host.
