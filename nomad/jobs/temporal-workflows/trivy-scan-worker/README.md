# trivy-scan-worker

Temporal worker that scans every running container image with Trivy
(server mode) and writes CVE results to a PostgreSQL `trivy` database
that the trivy-dashboard reads from. Listens on the
`trivy-task-queue`; started on schedule by a Temporal Schedule.

## Image

`registry.munchbox.cc/trivy-scan-worker:v0.2.0`

## Hostname / exposure

- No traefik
- Metrics on container port 9090, scraped via Consul

## Placement

- Constrained to `goren` or `stabler` -- bare-metal nodes with the
  reliable WAN access needed to talk to the Trivy DB server

## Dependencies

- Temporal at `temporal-server.service.consul:7233`
- Nomad API at `https://192.168.68.61:4646`; token from
  `secret/data/backup-worker`
- PostgreSQL `trivy` database at
  `haproxy-postgres.service.consul:5433` with `sslmode=verify-ca`;
  creds from `secret/data/trivy-dashboard`
- Vault `pki_int/cert/ca` rendered into `secrets/postgres-ca.crt`
- Tempo at `tempo.service.consul:4317`

## Notable configuration

- Host network
- 500 MHz / 512 MiB -- Trivy DB updates and image scanning are
  noticeably heavier than the other workers
- DB ssl mode `verify-ca` rather than `require`
