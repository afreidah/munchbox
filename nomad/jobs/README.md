# nomad/jobs/

All Nomad job definitions. Two flavors:

- **Pack jobs** (`<name>.hcl`) -- set variables consumed by the
  `munchbox-service` pack at `nomad/packs/registry/munchbox-service/`. The
  pack renders a standardized job template that handles Vault, Traefik,
  health checks, services, storage, logging, etc. Most services use this.
- **Raw jobs** (`<name>.nomad.hcl`) -- full Nomad job specs. Used when the
  job needs structure the pack doesn't express (system jobs running on
  every node, batch/periodic with custom dispatch, multi-task groups,
  unusual driver config).

The split is currently 25 pack, 41 raw (66 specs, excluding `deprecated/`).
Both deploy through the same `make run JOB=<name>` from `nomad/`.

> **Style guide:** [STYLE_GUIDE.md](./STYLE_GUIDE.md) -- job authoring
> rules, structural order, comment forms, when to use pack vs raw, vault
> wiring, traefik tag conventions. Self-contained.

---

## Layout

```
nomad/jobs/
+-- infrastructure/       # 29 jobs -- core cluster + ingress + identity (incl. dnsdist)
+-- monitoring/           #  9 jobs -- prom stack + exporters + alertmanager
+-- media/                # 10 jobs -- *arr stack + jellyfin
+-- web/                  # 10 jobs -- user-facing apps + dashboards
+-- temporal-workflows/   #  3 jobs -- backup / scan / cleanup workers
+-- logging/              #  3 jobs -- alloy + loki + tempo
+-- games/                #  2 jobs -- phlebotomy-game + zomboid
+-- deprecated/           #  parked jobs (specs kept for revival; not running)
```

Inside each category, one directory per job:

```
nomad/jobs/<category>/<job-name>/
+-- <job-name>.hcl           # OR <job-name>.nomad.hcl
+-- README.md                # (optional; only some have them currently)
+-- files/                   # config templates, static files (consul-template syntax)
```

---

## Deploying

From the `nomad/` directory:

```bash
source ../munchbox-env.sh        # exports NOMAD_TOKEN, VAULT_TOKEN, CONSUL_HTTP_TOKEN

make list                        # list every available job
make render JOB=<name>           # print the rendered HCL (pack jobs only)
make plan   JOB=<name>           # diff against running job
make run    JOB=<name>           # submit
make stop   JOB=<name>           # graceful stop (job stays in nomad)
make purge  JOB=<name>           # stop + purge from nomad state
make validate JOB=<name>         # nomad job validate
```

`JOB=<name>` is the directory name under `jobs/<category>/<name>/`, without
the path or `.hcl` extension. The Makefile finds the right file
automatically and routes to nomad-pack or `nomad job run` as appropriate.

Bulk targets exist too: `make render-all`, `make plan-all`, `make
validate-all` -- useful for CI / pre-merge verification.

---

## Pack vs raw -- when to use which

| Need | Use |
|---|---|
| Standard service (one task, one image, Vault secrets via template, optional Traefik) | **pack** |
| Standard batch (one-shot script in a container, periodic schedule) | **pack** |
| System job (one alloc per node) | **raw** -- pack doesn't model `type = "system"` cleanly |
| Multi-task group (e.g. main service + sidecar) | **raw** |
| Custom dispatch / unusual lifecycle | **raw** |
| Driver other than `docker` (raw_exec, exec, java) | **raw** |
| Multi-network mode, host_network with explicit interface | **raw** |

Default to pack. Drop to raw only when the pack can't express what you
need. Don't fork the pack -- extend it.

The pack lives at `nomad/packs/registry/munchbox-service/`. Its `variables.hcl`
documents every available knob (port, traefik, vault, templates, storage,
health, etc.).

---

## Shared variables

`nomad/shared.vars.hcl` holds variables every job can reference. Currently
just the two Pi-hole DNS server IPs (`pihole_1`, `pihole_2`). The Makefile
includes it for `nomad job run` calls on raw jobs that declare matching
`variable` blocks.

Adding a shared variable means it's in `shared.vars.hcl`, declared as a
`variable` block in any raw job that consumes it, and referenced in pack
jobs via the `env` knob or templates.

---

## Vault wiring

For pack jobs: set `vault = true` and provide a `templates` entry that
renders the secret into a file (or env var) at runtime:

```hcl
vault = true

templates = [
  { src = "service.env", dest = "secrets/service.env", env = true }
]
```

Then in `files/service.env`:

```
{{ with secret "secret/data/<path>" }}
SECRET_VALUE={{ .Data.data.<key> }}
{{ end }}
```

For raw jobs: include a `vault {}` block at the task level + a `template {}`
block rendering the secret. Workload identity (`identity { ... }`) is on
by default for new jobs.

If a Vault read fails with 403, **fix the policy in
`infrastructure/terragrunt/_env_helpers/vault-config.hcl`** (specifically
the `workload_secrets` list), then `terragrunt apply` on `global/vault-config/`.
Then `nomad job restart <name>` to re-fetch.

---

## Traefik routing

Pack jobs: set `traefik = true` and `traefik_host = "<name>.munchbox.cc"`.
The pack emits the right consul service tags for Traefik's
`consulcatalog` provider to pick up.

For non-default routing (multiple hosts, middlewares, plain HTTP +
HTTPS), drop the `traefik_host` shortcut and use the raw `tags` knob:

```hcl
traefik = false

tags = [
  "traefik.enable=true",
  "traefik.http.routers.<r>.rule=Host(`<host>`)",
  "traefik.http.routers.<r>.entrypoints=websecure",
  "traefik.http.routers.<r>.tls=true",
  "traefik.http.routers.<r>.middlewares=oauth2-proxy@file",
]
```

Common middlewares already registered in Traefik file-provider:

| Middleware | Use |
|---|---|
| `oauth2-proxy@file` | Auth gate via OAuth2 |
| `oauth2-proxy-errors@file` | Pair with oauth2-proxy; pretty error pages |
| `cf-tunnel-https@file` | Force HTTPS upgrade behind Cloudflare tunnel |

If a route is internal-only (LAN-reachable, not behind the CF tunnel),
**don't** include `oauth2-proxy` or `cf-tunnel-https`. Pi-hole admin routes
are a recent example: dropped both because the boxes aren't tunnel-exposed
and the network IS the auth boundary.

---

## Placement / constraints

| Need | Pack | Raw |
|---|---|---|
| Run anywhere | `node = "any"` (default) | omit constraints |
| Specific node | `node = "stabler"` | `constraint { attribute = "${node.unique.name}", value = "stabler" }` |
| On-prem only | `constraints = [{ attribute = "$${meta.cloud}", operator = "!=", value = "oracle" }]` | `constraint { attribute = "${meta.cloud}", operator = "!=", value = "oracle" }` |
| Oracle only | `value = "oracle"` instead of `!=` | same |
| GPU node | `constraints = [{ attribute = "$${meta.role}", value = "gpu" }]` | `constraint { attribute = "${meta.role}", value = "gpu" }` |
| One alloc per node | (use raw) | `type = "system"` |

The double `$$` in pack constraints escapes interpolation in the pack
template -- without it, the pack tries to substitute `${meta.cloud}` at
render time and the value won't propagate to the rendered job.

---

## Monitoring + observability

Most jobs are Prometheus-scraped via Consul service discovery. If a
service exposes `/metrics`:

1. Pack job: set `tags = ["monitoring", "<service>", "metrics"]` and make
   sure the consul service registers on the metrics port.
2. Add a scrape config to `nomad/jobs/monitoring/prometheus/files/
   prometheus.yml.tpl` under the right Consul-SD job.

Probe-shaped checks (HTTP up/down) go through `blackbox-exporter-external`
or `blackbox-exporter-internal` -- never inline `http_check` blocks. See
`monitoring/blackbox-exporter-*/README.md` for which to use.

---

## State management

- **Pack jobs** are rendered fresh on every `make run`. State lives in
  Nomad; nothing on disk to drift.
- **Raw jobs** are submitted as-written. If you edit and run again, Nomad
  diffs and rolls.
- **Restart semantics**: `make stop` keeps the job spec in Nomad
  (re-runnable). `make purge` removes it entirely.
- For batch/periodic jobs: `nomad job periodic force <name>` triggers a
  one-off dispatch without waiting for the cron.

---

## Related

- [STYLE_GUIDE.md](./STYLE_GUIDE.md) -- job authoring rules, structural
  order, comment forms, vault/traefik/placement patterns.
- [`nomad/packs/registry/munchbox-service/`](../packs/registry/munchbox-service/)
  -- the pack itself; `variables.hcl` is the complete knob catalog.
- [Top-level CLAUDE.md](../../CLAUDE.md) -- repo-wide conventions, deploy
  protocol, secrets handling.
- [Munchbox kanban](https://github.com/users/afreidah/projects/4) -- open
  job work tracked in Project #4.
