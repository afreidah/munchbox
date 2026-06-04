# cleanup-worker

Temporal worker that removes orphaned Nomad job data directories on
client nodes over SSH. Listens on the `cleanup-task-queue`; started on
schedule by a Temporal Schedule.

## Image

`registry.munchbox.cc/cleanup-worker:v0.2.4`

## Hostname / exposure

- No traefik
- Metrics on container port 9090, scraped via Consul

## Placement

- Pinned to `stabler` -- bare-metal node with SSH reachability to the
  whole cluster. Cannot share with `goren` because both bind
  host :9090 in host-net mode and goren already runs prometheus there.

## Dependencies

- Temporal at `temporal-server.service.consul:7233`
- Nomad API at `https://192.168.68.61:4646`; token from
  `secret/data/backup-worker`
- SSH CA -- private key from `secret/data/ssh/backup-worker`, host CA
  pub from `ssh-host-signer/config/ca`, client cert signed via
  `ssh-client-signer/sign/client-service` with
  `valid_principals=root,ubuntu`
- Tempo at `tempo.service.consul:4317`

## Notable configuration

- Host network so SSH out to nodes uses the host routing table
- Signed-cert template uses `change_mode = "noop"` -- cert
  re-signing always produces different output, so without this the
  task would restart on every Vault lease renewal
- 100 MHz / 32 MiB resources -- this worker barely does anything until
  its schedule fires
