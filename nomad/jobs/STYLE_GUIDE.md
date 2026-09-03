# nomad/jobs/ -- Style Guide

Authoritative for Nomad job specs in this repo. Self-contained.

Organized by file type and concern. Comment rules and patterns are stated
next to the structure they apply to.

---

## 1. File header / preamble

Every `.hcl` and `.nomad.hcl` job file opens with:

```hcl
# -------------------------------------------------------------------------------
# <Service Name> -- <Short Role>
#
# Project: Munchbox / Author: Alex Freidah
#
# 2-4 sentences describing what this service is, what it talks to, and any
# important caveats. Stay factual -- no migration narration, no bug history.
# -------------------------------------------------------------------------------
```

Rules:
- Divider is **79 `#-` chars**.
- Title line is `<Service Name> -- <Short Role>` (em-dash `--`).
- `Project: Munchbox / Author: Alex Freidah` on its own line.
- 2-4 sentence description. No bullet points in the header.
- Header purpose is "what this service IS", not "what was here before".

For raw jobs (`.nomad.hcl`) the header is the same shape. For pack jobs
(`<name>.hcl`) it sits above the variable assignments.

---

## 2. Comments -- strict binary rule

Same rule as cinc and terragrunt. **Two acceptable shapes; no middle
form.**

### (a) Single-line markers

```hcl
# --- Core job configuration ---
name        = "pihole-exporter"
image       = "ekofr/pihole-exporter:v1.2.0"
```

- `# --- text ---` form.
- ~60 chars max. Promote to a box if longer.
- No blank line after.

### (b) Section box

```hcl
# ---------------------------------------------------------------------------
# Task Group: coredns
# ---------------------------------------------------------------------------

group "coredns" {
  ...
}
```

- 79-char divider for file-level / major sections.
- 75-char divider for in-file logical chunks inside a raw job.
- One blank line **after** the closing divider.

### Wrong (multi-line `#` form)

```hcl
# Probes pihole.munchbox.cc through the LB and per-node URLs.
# Pi-hole admin requires no auth on the LAN, so plain http_2xx works.
# The internal blackbox runs on-prem so we don't ride the WG tunnel.
- "http://pihole.munchbox.cc/admin/"
```

### Right (compress)

```hcl
# --- Internal-only; LAN auth boundary, no oauth in front ---
- "http://pihole.munchbox.cc/admin/"
```

### Forbidden content

- Migration narration (`# was ansible, now nomad`).
- Bug history (`# was broken until commit abc`).
- `TODO`/`FIXME`; open a GH issue instead.

---

## 3. Pack jobs (`<name>.hcl`)

The munchbox-service pack handles the heavy lifting. Pack jobs are
variable assignments grouped by concern, each group with a `# --- ... ---`
marker.

### Canonical shape

```hcl
# -------------------------------------------------------------------------------
# Pi-hole Exporter -- Metrics for both Pi-hole instances over the LAN
#
# Project: Munchbox / Author: Alex Freidah
#
# Single eko/pihole-exporter instance scraping green + logan via comma-separated
# PIHOLE_HOSTNAME.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "pihole-exporter"
image       = "ekofr/pihole-exporter:v1.2.0"
port        = 9617
static_port = 9617
size        = "tiny"
memory      = 64
vault       = true

# --- Traefik routing ---
traefik = false

# --- Health check (eko's /metrics scrapes pihole synchronously, ~3s per hit) ---
health_path     = "/metrics"
health_timeout  = "10s"
health_interval = "30s"

# --- Environment (static; secrets come via template) ---
env = {
  TZ              = "America/Los_Angeles"
  PIHOLE_HOSTNAME = "192.168.68.62,192.168.68.64"
  PIHOLE_PROTOCOL = "http"
  PIHOLE_PORT     = "80"
  PORT            = "9617"
}

# --- Vault template renders the password into env at runtime ---
templates = [
  { src = "pihole.env", dest = "secrets/pihole.env", env = true }
]

# --- Service tags ---
tags = ["monitoring", "pihole-exporter", "metrics"]

# --- Placement: any on-prem nomad client (NOT oracle) ---
node = "any"
constraints = [
  { attribute = "$${meta.cloud}", operator = "!=", value = "oracle" }
]
```

### Section order

Preserve this order; reviewers scan top-to-bottom for the canonical knobs:

1. **Core job configuration** -- `name`, `image`, `port` / `static_port`,
   `size` / `cpu` / `memory`, `vault`, `host_network` if relevant.
2. **Traefik routing** -- `traefik`, `traefik_host`, OR `traefik = false` +
   explicit `tags` for non-default routing.
3. **Health check** -- `health_path`, `health_timeout`, `health_interval`,
   `health_type`. Only override the timeout/interval when the default
   (3s / 10s) won't fit.
4. **Environment** -- `env { ... }` map.
5. **Templates** -- `templates` array (Vault secret renders).
6. **Service tags** -- `tags` array (if not already in Traefik routing).
7. **Storage** -- `storage`, `storage_path` if needed.
8. **Placement** -- `node`, `constraints`.

Omit sections that don't apply rather than including empty/default values
"for completeness".

### Pack-specific gotchas

- **Constraint string interpolation**: use `$${meta.X}`, not `${meta.X}`.
  The double `$$` escapes the pack template's render pass so the raw
  `${meta.X}` survives to the rendered job.
- **`name` always matches the directory name.** `make` uses the dir
  to find the job; the rendered job uses the `name` value. They must
  agree.
- **Image pins are explicit.** No `:latest`. If you bump, bump the tag.
- **`size`** picks from `tiny` / `small` / `medium` / `large` /
  `extra-large` in the pack. Use it instead of raw `cpu` + `memory`
  when one of the standard sizes fits -- it keeps the resource footprint
  uniform across the fleet.

---

## 4. Raw jobs (`<name>.nomad.hcl`)

When the pack can't model what you need (`type = "system"`, multi-task
groups, periodic with weird config, raw_exec driver), drop to raw.

### Structural order

**Job level** (top to bottom):
1. `region`, `datacenters`, `node_pool`, `type`, `priority`, `namespace`
2. `meta { ... }`
3. `update { ... }`
4. `reschedule { ... }`
5. `constraint { ... }` blocks
6. `vault { ... }` (when used job-level)
7. `group { ... }` blocks

**Group level**:
1. `count`
2. `meta { ... }`
3. `constraint { ... }` blocks
4. `network { ... }`
5. `volume { ... }`
6. `ephemeral_disk { ... }`
7. `restart { ... }`
8. `reschedule { ... }`
9. `service { ... }` (group-level)
10. `task { ... }` blocks

**Task level**:
1. `driver`
2. `identity { ... }`
3. `vault { ... }` (task-level if not job-level)
4. `config { ... }`
5. `env { ... }`
6. `template { ... }` blocks
7. `volume_mount { ... }`
8. `service { ... }` (task-level)
9. `resources { ... }`
10. `lifecycle { ... }` (for sidecars / init tasks)
11. `kill_signal`, `kill_timeout`

If you find yourself reordering an existing job's blocks for a single
edit, restraint -- only reorder if you're touching the whole task.

### Section boxes

Use 75-char `#---` dividers inside a raw job, with a one-line title:

```hcl
job "coredns" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel = 1
    stagger      = "30s"
  }

  # ---------------------------------------------------------------------------
  # Task Group: coredns
  # ---------------------------------------------------------------------------

  group "coredns" {
    ...
  }
}
```

Major sections to box: Metadata, Update Strategy, Constraints, Task Group,
each Task, Restart Policy, Service, Templates, Resources.

Don't box trivial blocks (`meta {}`, single-field blocks).

### Variables in raw jobs

Variables at the top of the file, before the `job` block:

```hcl
variable "pihole_1" {
  type    = string
  default = "192.168.68.62"
}

variable "cloudflare" {
  type    = string
  default = "1.1.1.1"
}
```

Defaults match `shared.vars.hcl` so the job runs even if the Makefile
doesn't pass the var-file. The Makefile passes `-var-file=shared.vars.hcl`
for every raw-job invocation.

---

## 5. Templates (`files/<name>`)

Consul-template syntax (`{{ ... }}`). Vault reads use the data API path:

```
{{ with secret "secret/data/<path>" }}
SECRET={{ .Data.data.<field> }}
{{ end }}
```

For env-file destinations: one `KEY=value` per line. For config-file
destinations: native syntax of the consuming program.

### The `{{ ... }}` escape trap (Grafana dashboards specifically)

If the rendered file itself uses `{{ ... }}` (Grafana dashboard JSON,
Promtail config, etc.), the consul-template renderer eats the braces.
Escape them with backticks:

```json
"legendFormat": "{{ `{{` }}hostname{{ `}}` }}"
```

This is a real footgun. See issue #122 in github for the long-term
fix (moving Grafana dashboards out of nomad templates entirely).

### `change_mode`

When a template change shouldn't restart the task (e.g. SSH client cert
re-issuance always produces a different binary blob but the running
service doesn't care), set `change_mode = "noop"` on the `template {}`
block. Default is `restart`.

```hcl
template {
  data        = "..."
  destination = "secrets/ssh-cert.pub"
  change_mode = "noop"
}
```

Pack jobs accept `change_mode` per template entry:

```hcl
templates = [
  { src = "ssh-cert.tpl", dest = "secrets/ssh-cert.pub", change_mode = "noop" }
]
```

---

## 6. Vault wiring

### Pack jobs

```hcl
vault = true

templates = [
  { src = "service.env", dest = "secrets/service.env", env = true }
]
```

And `files/service.env`:

```
{{ with secret "secret/data/<path>" }}
SECRET={{ .Data.data.<field> }}
{{ end }}
```

### Raw jobs

Job-level when every task needs Vault:

```hcl
vault {
  role        = "nomad-workloads"
  change_mode = "noop"
}
```

Task-level when only one task in a group needs Vault. Workload identity is
on by default.

### `change_mode` on the `vault {}` block

Always set `change_mode = "noop"`. This is separate from the `template {}`
`change_mode` above and is easy to miss -- it defaults to `restart`.

Nomad mints the workload-identity JWT with `default_identity.ttl = "1h"`
(agent config, cinc-managed) and re-authenticates to Vault at half-life. A
login always returns a *new* token -- there is no renew-via-login -- so the
default `restart` bounces the task every 30 minutes, forever. That is ~48
restarts/task/day across every Vault-using job.

`noop` is safe because nothing here needs the restart:

- `template {}` consumers: consul-template picks the new token up in-process.
- Direct consumers read `/secrets/vault_token`, which Nomad rewrites on
  rotation. The `nomad-temporal-jobs` shared client re-reads it every 60s;
  s3-orchestrator's `tokenRenewalLoop` every 5m. Both beat the 1h TTL.

If a new job reads the token *once* at startup and caches it, fix the job to
re-read the file rather than reverting to `restart`.

### Adding a new Vault secret path

1. Add the path to `infrastructure/terragrunt/_env_helpers/vault-config.hcl`
   -> `workload_secrets` list (just the path under `secret/data/`).
2. `cd infrastructure/terragrunt/global/vault-config && terragrunt apply`.
3. `nomad job restart <name>` to re-fetch with the new policy.

A 403 from a template render means the policy is wrong -- fix in (1),
not by changing the secret path in the job.

---

## 7. Service tags

Tags for Consul service registration. Most are Traefik-related, with a
few for monitoring/discovery.

### Traefik default routing (pack)

```hcl
traefik      = true
traefik_host = "<name>.munchbox.cc"
```

The pack emits the standard router + service tags for `<name>.munchbox.cc`
with `websecure` + `tls`.

### Traefik custom routing (raw tags)

```hcl
traefik = false

tags = [
  "traefik.enable=true",
  "traefik.http.routers.<r>.rule=Host(`<host>`)",
  "traefik.http.routers.<r>.entrypoints=websecure",
  "traefik.http.routers.<r>.tls=true",
  "traefik.http.routers.<r>.middlewares=oauth2-proxy@file",

  # Plain HTTP fallback (Cloudflare tunnel hits :80)
  "traefik.http.routers.<r>-http.rule=Host(`<host>`)",
  "traefik.http.routers.<r>-http.entrypoints=web",
  "traefik.http.routers.<r>-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file",
]
```

Backtick-escape host rules. Indent for readability if the list is long.

### Middleware catalog

| Middleware | Use |
|---|---|
| `oauth2-proxy@file` | Auth via OAuth2 (required for public routes) |
| `oauth2-proxy-errors@file` | Pair with `oauth2-proxy@file` |
| `cf-tunnel-https@file` | Force HTTPS upgrade behind Cloudflare tunnel |

### Internal-only routes

Routes for services not exposed through the CF tunnel (Pi-hole admin,
internal dashboards reachable only on LAN) **must not** include
`oauth2-proxy@file` or `cf-tunnel-https@file`. The network is the auth
boundary; adding oauth in front breaks blackbox probes and any
non-browser client.

### Monitoring tags

```hcl
tags = ["monitoring", "<service>", "metrics"]
```

Match the `services` list in the relevant `prometheus.yml.tpl` scrape
config. Adding a new exporter means adding to both.

---

## 8. Placement / constraints

### Pack

```hcl
node = "any"               # any client (default)
node = "<hostname>"        # specific named node

constraints = [
  { attribute = "$${meta.cloud}", operator = "!=", value = "oracle" }
]
```

### Raw

```hcl
constraint {
  attribute = "${node.unique.name}"
  value     = "stabler"
}

constraint {
  attribute = "${meta.cloud}"
  operator  = "!="
  value     = "oracle"
}
```

### Pack escape gotcha

In pack jobs, `${meta.X}` interpolates at pack render time (resolving to
empty). Use `$${meta.X}` -- the double `$$` escapes to literal `${meta.X}`
in the rendered job, which Nomad then interprets correctly.

### `meta.*` keys available

| Key | Set on |
|---|---|
| `meta.cloud` | `oracle` on oracle nodes, otherwise unset |
| `meta.role` | `ingress` on stabler+goren, `gpu` on nomad-client-04, etc. |

Adding a new `meta.*` value means setting it via the nomad-config cinc
cookbook (per-node attribute) and re-converging the relevant nodes.

---

## 9. Health checks

Pack defaults: `http` type, `/health` path, 3s timeout, 10s interval.

Override when the default won't fit:

```hcl
health_path     = "/metrics"
health_timeout  = "10s"
health_interval = "30s"
```

Raw jobs use standard Nomad `check {}` blocks inside `service {}`. Prefer
`http` over `tcp` -- `tcp` only confirms the listener exists, not that the
service is functional.

### Watch the timeout for slow scrapes

Services that scrape upstream on every `/metrics` hit (eko's pihole
exporter, some redis exporters) can take seconds. Bump the timeout to
10s+ and the interval to 30s+ so health checks don't cascade into
restart loops.

### When NOT to use HTTP health

System jobs (`type = "system"`) that don't expose HTTP -- fall back to a
script check or no check at all rather than wedging a fake endpoint in.

---

## 10. Lifecycle blocks (sidecars + init tasks)

```hcl
task "init-cert" {
  lifecycle {
    hook    = "prestart"
    sidecar = false
  }
  ...
}

task "vault-agent" {
  lifecycle {
    hook    = "prestart"
    sidecar = true
  }
  ...
}
```

Rules:
- `hook = "prestart"` for setup tasks (cert generation, schema migration).
- `sidecar = true` for long-running companion tasks that share the alloc
  lifecycle with the main task.
- `sidecar = false` (default) for one-shot init.
- `poststart` only for tasks that genuinely need the main task running
  first.

---

## 11. Resources

Pack: use `size = "tiny" / "small" / "medium" / "large"`. Drop to raw
`cpu` + `memory` only when none of the standard sizes fit (e.g. very
small batch jobs, GPU jobs).

Raw:

```hcl
resources {
  cpu    = 100
  memory = 128
}
```

Rules:
- `cpu` in MHz (Nomad convention, 100 ~ 0.1 core).
- `memory` in MiB.
- Don't pad numbers ("just in case 2x"). Measure and pin.
- `memory_max` only when the service has a bursty profile.

---

## 12. Common ops

```bash
# From nomad/
source ../munchbox-env.sh

make plan JOB=<name>      # diff
make run  JOB=<name>      # submit
make stop JOB=<name>      # graceful stop, keep spec
make purge JOB=<name>     # remove from nomad

nomad job status <name>            # current state
nomad alloc status <alloc-id>      # one alloc
nomad alloc logs <alloc-id>        # stdout
nomad alloc logs -stderr <alloc-id>
nomad alloc exec <alloc-id> sh     # interactive shell (when busybox available)
```

For batch/periodic jobs:

```bash
nomad job periodic force <name>    # fire one-off dispatch
```

For health-check diagnosis:

```bash
nomad alloc status <alloc-id>      # look at "Recent Events" + service Check IDs
```

---

## 13. Migration / refactor rules

- **Match existing job exactly on takeover.** When taking over a job from
  ansible or a manual `nomad job run`, pull the current rendered spec
  with `nomad job inspect <name>` and template against THAT. Don't trust
  "what the playbook should have produced".
- **Preserve per-node `meta {}` blocks.** If a task group / task has
  `meta { role = "ingress" }` etc., reproduce them. System-job allocs
  constrain on these.
- **Bump image tags one at a time.** Bumping multiple containers in one
  PR makes the bad-revert harder when one of them breaks.
- **Never delete a stateful job without backup.** `make purge` is
  destructive. Check `nomad volume status` and any host-volume mounts
  before purging.

---

## 14. Quick reference: file checklist

When adding or modifying a job, verify before commit:

- [ ] Header banner with em-dash title + Project/Author + 2-4 sentence
      description.
- [ ] No multi-line `# foo / # bar` comments.
- [ ] Pack section order: core -> traefik -> health -> env -> templates ->
      tags -> storage -> placement.
- [ ] Raw section order respected at job / group / task levels.
- [ ] Image pinned to an explicit tag (no `:latest`).
- [ ] If Vault is used: matching path in
      `infrastructure/terragrunt/_env_helpers/vault-config.hcl` ->
      `workload_secrets`.
- [ ] If Traefik is used: middlewares match exposure level (no oauth on
      LAN-only routes).
- [ ] If consul-template + `{{ ... }}` in rendered output: escapes
      applied.
- [ ] If a constraint uses `meta.*`: double `$$` in pack, single `$` in
      raw.
- [ ] If a Prometheus scrape target was added: matching entry in
      `prometheus.yml.tpl`.
- [ ] `make plan JOB=<name>` shows a clean expected diff.
