# loki

Centralized log aggregation with label-based indexing. Receives logs from
the per-node Alloy / Promtail agents and stores them on local disk.
Queried via Grafana with LogQL.

## Image

`grafana/loki:3.7.2`

## Hostname / exposure

- `loki.munchbox` (internal-only hostname, no public `.cc`)
- HTTPS router via Traefik
- Host-networked on static port 3100

## Placement

- Pinned to `nomad-client-02` (`node = "nomad-client-02"`); co-located with
  Tempo so the observability state lives on one host

## Dependencies

- Host volume `/opt/nomad/data/loki` (pre-created manually, no init task)
- Promtail / Alloy agents (push logs in)
- Grafana (query layer)

## Notable configuration

- Args `-config.file=/etc/loki/config.yaml`
- Templates: `config.yaml` and `alert_rules.yaml` rendered into the container
- Health probe `/ready`
- 1 GiB reserved memory, 2 GiB cap
