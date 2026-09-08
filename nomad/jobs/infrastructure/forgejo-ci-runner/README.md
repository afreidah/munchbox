# forgejo-ci-runner

Parameterized batch job. Each dispatch registers one Forgejo Actions runner,
runs a single queued job, and exits. Replaces the long-lived `forgejo-runner`
daemon.

Dispatches come from the `ci-runner-scaler` Temporal workflow
(`nomad-temporal-jobs/runnerscaler`), which polls the Forgejo Actions API for
waiting jobs, reconciles them against the runners already active, and mints a
registration token per dispatch.

## image

`code.forgejo.org/forgejo/runner:12.13.0`

## dispatch

```
nomad job dispatch \
  -meta repo_url=http://forgejo.service.consul:30028/alex/munchbox \
  -meta runner_token=<registration-token> \
  -meta labels=ubuntu-latest \
  forgejo-ci-runner
```

- `repo_url`, `runner_token` -- required
- `labels` -- optional; the scaler uses it to bucket runners against queued jobs.
  The runner registers the full label set regardless, because a runs-on label
  arrives bare (`ubuntu-latest`) and carries no image.

## hostname / exposure

- internal-only, no traefik
- registers against `http://forgejo.service.consul:30028`; the public host sits
  behind oauth2-proxy, which a runner cannot authenticate through

## placement

- `node_pool = "oracle"` with `meta.tier != "micro"` -- a workflow container does
  not fit beside the runner on the 1 GB micro nodes
- `count = 1` per dispatch; concurrency is capped by `maxConcurrent` in the
  scaler config, not here
- `restart`/`reschedule` attempts are 0: a finished or failed runner is never
  revived. If its job is still queued the scaler dispatches a fresh one.

## dependencies

- Forgejo server (Consul service `forgejo`) for registration and job pickup
- Docker socket on the host (`/var/run/docker.sock`) -- privileged, runs sibling
  containers for each job
- internal registry `registry.munchbox.cc` for the `ops-build-image` label
- Consul DNS at `192.168.68.64` and `192.168.68.62` for job containers
  (forced via `container.options --dns`)

No `vault{}` block: workflows read their cluster credentials from Forgejo
repository action secrets, synced from Vault by terragrunt
(`_env_helpers/forgejo-secrets.hcl`). The runner needs no secret of its own
beyond the registration token in its dispatch meta.

## terragrunt

- `_env_helpers/consul-kv.hcl` -- the `alex/munchbox` entry in `runners/config`
  sets `mode = "forgejo"` and points both label profiles at this job
- `_env_helpers/vault-config.hcl` -- the `ci-runner-scaler` policy reads the
  instance API token at `secret/forgejo/scaler`

## notable configuration

- `capacity: 1` pairs with `one-job`: one workflow job per allocation
- the cache server is disabled -- its directory dies with the allocation, so it
  would only ever miss
- `one-job --wait` blocks until a job is assigned rather than exiting on a
  momentarily empty queue, which would race the dispatch that created the runner
- `kill_timeout = 60s` to let an in-flight job drain
