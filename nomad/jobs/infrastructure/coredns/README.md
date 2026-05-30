# coredns

DNS load balancer that distributes queries across both Pi-holes (var.pihole_1
and var.pihole_2). Runs as a system job so every node has a local DNS
forwarder on port 5354, which each node's dnsmasq uses for non-Consul lookups.

## Image

`coredns/coredns:1.13.2`

## Hostname / exposure

- Internal-only Consul service `coredns` on port 5354 (host network)
- Prometheus metrics on static 9153 (`coredns-metrics` Consul service)
- `traefik.enable=false`

## Placement

- `type = system`, `node_pool = all`, priority 80
- Lands on every node so dnsmasq can point at localhost

## Dependencies

- Pi-holes at `var.pihole_1` (192.168.68.62) and `var.pihole_2`
  (192.168.68.64) -- upstreams via `forward .` with round_robin + health check
- Tempo (`tempo.service.consul:9411`) for Zipkin traces
- Consul agent DNS on `127.0.0.1:8600` for `.consul` queries
- Prometheus scrapes 9153

## Notable configuration

- Cache: 300s success / 60s denial
- Health endpoint on `:8053` (avoid 8080 conflicts)
- 300 MHz / 64 MiB; CPU sized for query bursts under load
- Update strategy: `max_parallel = 1`, `stagger = 30s`
