# temporal

Workflow orchestration engine that powers automated backups and vulnerability
scanning. The server exposes a gRPC API on 7233; the UI is a separate job.

## Image

- temporal-server: `temporalio/server:1.29.1`
- temporal-ui: `temporalio/ui:2.44.1`

## Hostname / exposure

- temporal-server: internal-only, gRPC on static 7233, no Traefik
- temporal-ui: `temporal.munchbox.cc`, HTTPS + HTTP routers, both gated by
  `oauth2-proxy@file`

## Placement

- temporal-server: pinned to `nomad-client-03` (`node = "nomad-client-03"`),
  host-networked
- temporal-ui: any node except `oraclenode1` / `oraclenode2`

## Dependencies

- Patroni (Postgres) -- `temporal` and `temporal_visibility` databases.
  Server is currently wired through hardcoded DNS to goren (`dns =
  ["192.168.68.60"]`) because multi-IP Consul DNS for haproxy-postgres
  bypasses the HAProxy port and lands on raw 5432
- temporal-ui uses Pi-hole DNS (`192.168.68.64`, `192.168.68.62`) to resolve
  `temporal-server.service.consul:7233`
- Vault: TLS material + env via `temporal-env.tpl` and `ca.crt.tpl`
- Tempo OTLP `tempo.service.consul:4317` (gRPC)

## Notable configuration

- Server runs all four services in one process
  (`SERVICES=frontend,history,matching,worker`)
- UI explicitly disables TLS host verification and server name (server is
  reached over the LAN, not via Traefik)
- 500 MHz / 512 MiB server reservation
- Health check disabled on the server (gRPC, not HTTP)
