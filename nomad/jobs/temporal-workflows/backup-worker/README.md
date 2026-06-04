# backup-worker

Temporal worker that runs the cluster's backup workflows: Nomad
snapshots, Consul snapshots, and per-database PostgreSQL dumps from
the Patroni cluster. Local copies land on `/mnt/gdrive`; off-site
copies go to s3-orchestrator. Started on schedule by a Temporal
Schedule (managed in `infrastructure/terragrunt`).

## Image

`registry.munchbox.cc/backup-worker:v0.2.0`

## Hostname / exposure

- No traefik
- Metrics on container port 9090, scraped via Consul

## Placement

- Pinned to `nomad-client-03` -- the node with `/mnt/gdrive` mounted

## Dependencies

- Temporal at `temporal-server.service.consul:7233` on the
  `backup-task-queue`
- Nomad API at `https://192.168.68.61:4646` (stabler) with TLS via
  the mounted vault intermediate CA; token from
  `secret/data/backup-worker`
- Consul token from `secret/data/consul/backup-worker-token`
- Patroni via PG password from `secret/data/postgres-shared/root`
- s3-orchestrator at `http://s3-orchestrator.service.consul:9000`,
  bucket `unified`, credentials from `secret/data/s3-orchestrator`
- Tempo at `tempo.service.consul:4317`

## Notable configuration

- Custom `dns { servers = ["127.0.0.53"] }` so `.consul` lookups go
  through the host's stub resolver -- avoids pi-hole rewriting
  `s3-orchestrator.service.consul` to a wildcard goren IP
- Memory pinned at 512 MiB even though steady-state is ~30 MiB;
  Postgres dumps OOM at the smaller limit
- 30s kill timeout to let in-flight Temporal activities flush
