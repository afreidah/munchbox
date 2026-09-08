# forgejo-runner

Forgejo Actions runner (`act_runner`) that picks up CI jobs from the local
Forgejo server and executes them in Docker containers on the Oracle ARM nodes.

## image

`code.forgejo.org/forgejo/runner:12.13.0`

## hostname / exposure

- internal-only, no traefik
- registers itself with the Forgejo server discovered via Consul
  (`forgejo.service.consul`)

## placement

- `node_pool = "oracle"` with `meta.tier != "micro"` and `distinct_hosts`
- `count = 2`, so one runner per non-micro Oracle ARM node
- runs in daemon mode (long-lived `act_runner daemon`), not one-shot

## dependencies

- Forgejo server (Consul service `forgejo`) for job pickup
- Vault `secret/data/forgejo-runner` for the registration token
- Docker socket on the host (`/var/run/docker.sock`) -- privileged, runs sibling
  containers for each job
- internal registry `registry.munchbox.cc` for the `ops-build-image` label
- Consul DNS at `192.168.68.64` and `192.168.68.62` for job containers
  (forced via `container.options --dns`)

## notable configuration

- privileged container with host network so job containers can reach cluster
  services
- runner labels include `ops:docker://registry.munchbox.cc/ops-build-image:latest`
  so workflows can target the in-house build image
- runner capacity is 1 per instance (2 concurrent jobs cluster-wide)
- `kill_timeout = 60s` to let in-flight jobs drain
