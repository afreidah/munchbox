<div align="center">

<img src="assets/munchbox.png" alt="munchbox" width="400">

# Munchbox Cloud - Homelab Infrastructure Platform

### Production-Grade Self-Hosted Infrastructure on HashiCorp Stack

[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red.svg)](LICENSE)
[![CI](https://github.com/afreidah/munchbox/actions/workflows/ci.yml/badge.svg)](https://github.com/afreidah/munchbox/actions/workflows/ci.yml)

</div>

---

A homelab cluster the size of a small production environment. Roughly **66
Nomad jobs**, **16 Cinc (Chef) cookbooks**, and **43 Terragrunt
modules**, running on bare-metal Pi 5s, Proxmox VMs, and Oracle Free Tier,
joined by a WireGuard mesh and fronted by Cloudflare.

It hosts media (Jellyfin, the *arr stack), the operator's
public personal-site stack (`alexfreidah.com`), self-hosted Git + CI
(Forgejo + runners + GitHub Actions self-hosted runners), and infrastructure
dense enough that it borders on a small startup's prod: HA PostgreSQL via
Patroni, mTLS everywhere via Vault PKI, OAuth2-fronted ingress, multi-cloud
S3 replication across **13 backends**, distributed tracing through Tempo,
and a Temporal-driven backup / scan / cleanup loop.

> This file is the project-wide overview. **Per-area READMEs and style
> guides live next to the code they document** -- `infrastructure/cinc/`,
> `infrastructure/terragrunt/`, and `nomad/jobs/` each have their own
> `README.md` + `STYLE_GUIDE.md`.

---

## Cluster topology

```
                          CLOUDFLARE EDGE  (public, *.munchbox.cc + alexfreidah.com)
                                   |
                            cloudflared tunnel
                                   |
                                   v
              +-------------------------------------+
              |       INGRESS PAIR (keepalived)     |
              |                                     |
              |  goren  192.168.68.60   * VRRP A    |       * holds VIPs:
              |  Pi5 ARM, server + ingress          |         .50 = traefik
              |                                     |         .49 = wireguard
              |  nomad-client-05  192.168.68.74     |
              |  Proxmox VM (rubirosa), 28G RAM     |
              |                                     |
              |  Both: Traefik + cloudflared        |
              |        + oauth2-proxy + keepalived  |
              +-------------------------------------+
                                   |
                                   v
   +-- server fleet (consul + nomad + vault) ----+
   |  goren            192.168.68.60   Pi5 ARM   |
   |  stabler          192.168.68.61   Pi5 ARM   |
   |  nomad-server-03  192.168.68.58   x86 VM    |
   +---------------------------------------------+

   +-- client fleet (Proxmox VMs) ---------------+ +-- hypervisors -----+
   |  nomad-client-01  fontana       .67 (13G)   | | cabot      .59     |
   |  nomad-client-02  mccoy         .72 (15G)   | | fontana    .65     |
   |  nomad-client-03  cabot         .71 ( 7G)   | | mccoy      .63 (*) |   (*) NFS exports
   |  nomad-client-04  rubirosa  **  .73 (28G)   | | rubirosa   .69 (*) |       /mnt/gdrive
   |  nomad-client-05  rubirosa      .74 (28G)   | +--------------------+       /tank
   +---------------------------------------------+
       (**) GPU passthrough + /tank media SSD

   +-- Cinc/Chef server -------------------------+
   |  cinc-server      192.168.68.99             | <- Proxmox VM on rubirosa
   +---------------------------------------------+

   +-- DNS (not Chef-managed; armv6 Pi 1) -------+
   |  green   192.168.68.62   Pi-hole + unbound  | <- managed by terragrunt
   |  logan   192.168.68.64   Pi-hole + unbound  |    remote-files module
   +---------------------------------------------+
       LAN clients hit dnsdist on the ingress VIP (.50:53), which
       load-balances both Pi-holes; .consul -> local agent.

   +-- Oracle Free Tier (WireGuard mesh, 10.200.0.0/24) ---------------+
   |  oracle-node-1   E2.1.Micro x86 AMD       wg 10.200.0.11   1G RAM |
   |  oracle-node-2   E2.1.Micro x86 AMD       wg 10.200.0.12   1G RAM |
   |  oracle-arm-1    A1.Flex ARM 2c           wg 10.200.0.13  12G RAM | <- MinIO (80G OCI block vol)
   |  oracle-arm-2    A1.Flex ARM 2c           wg 10.200.0.14  12G RAM | <- MinIO (80G OCI block vol)
   |                                                                   |
   |  Runs: oauth2-proxy, oracle-watchdog, theme-server, vault-ui,     |
   |        forgejo-runner, blackbox-exporter-external, kavita         |
   +-------------------------------------------------------------------+
```

**Network zones**

| Zone | CIDR | Where |
|---|---|---|
| Home LAN | `192.168.68.0/24` | Bare metal + Proxmox + Pi-hole hosts |
| WireGuard mesh | `10.200.0.0/24` | Oracle <-> ingress (`wg0` / `wg1`) |
| Traefik VIP | `192.168.68.50` | keepalived VRRP, MASTER holds it |
| WireGuard VIP | `192.168.68.49` | keepalived; oracle peers handshake here |
| OCI VCN | `10.100.0.0/16` | Oracle subnet (out-of-band; nodes reach LAN via WG) |

---

## Compositional architecture

Three layers, each owning a stable interface to the next:

```
+---------------------------------------------------------------------+
|  TERRAGRUNT       declarative substrate                             |
|                                                                     |
|  +- provisions    OCI VCN + instances + block volumes               |
|  |                Proxmox VMs                                       |
|  |                OCI / IBM / Cloudflare R2 S3 buckets + HMAC creds |
|  |                OCI KMS key (Vault auto-unseal)                   |
|  |                Cloudflare DNS + tunnel config                    |
|  |                Pi-hole DNS records + runtime config              |
|  |                                                                  |
|  +- manages       Vault mounts / policies / PKI / SSH-CA /          |
|  |                JWT / AppRole                                     |
|  |                Consul ACLs, Nomad ACLs                           |
|  |                Forgejo CI secrets (sync from Vault)              |
|  |                Vaultwarden items (sync from Vault)               |
|  |                oauth2-proxy secret material                      |
|  |                Proxmox PVE users                                 |
|  |                                                                  |
|  +- ships         Static files + restart hooks to non-Chef Pi-hole  |
|                   nodes via the remote-files module                 |
|                                                                     |
+-------------------------------+-------------------------------------+
                                |
                                v  (bootstrap module renders cloud-init
                                    that triggers first cinc-client run)
+-------------------------------+-------------------------------------+
|  CINC / CHEF      per-node convergence                              |
|                                                                     |
|  Cloud-init drops the org validator + encrypted_data_bag_secret +   |
|  client.rb + first-boot.json. cinc-client runs role[<hostname>]:    |
|                                                                     |
|  munchbox_base   ->  OS baseline: PKI trust, apt + munchbox repo,   |
|                      time, journald, sshd hardening, /etc/hosts,    |
|                      sysctl, resolv.conf                            |
|  cinc_client     ->  hourly timer + data-bag secret                 |
|  vault_agent     ->  AppRole -> /run/vault-agent/token              |
|  sshd_ca         ->  Vault SSH-CA host + user cert wiring           |
|  vault_pki_trust ->  pki_int CA into system trust + /opt/nomad/tls  |
|  vault_cert_mgr  ->  daemon: renews consul/nomad/vault mTLS certs   |
|  consul + dns    ->  cluster join + dnsmasq forwarder for .consul   |
|  docker          ->  daemon.json with insecure registry on Consul   |
|  nomad           ->  cluster join with workload identity to Vault   |
|  wireguard       ->  static route to oracle mesh (proxmox VMs)      |
|  cni             ->  bridge networking plugins for Nomad            |
|  nfs::client     ->  mount /mnt/gdrive from mccoy                   |
|                                                                     |
|  Oracle nodes add: wireguard interface, oracle::watchdog,           |
|                    minio_mount (arm-1/2)                            |
|  GPU node adds:    nvidia::install                                  |
|  Hypervisors get:  proxmox_host (ZFS ARC cap, gvt_g, vfio,          |
|                    zfswatcher)                                      |
|                                                                     |
+-------------------------------+-------------------------------------+
                                |
                                v  (Nomad agents up, registered in Consul)
+-------------------------------+-------------------------------------+
|  NOMAD JOBS       workloads                                         |
|                                                                     |
|  25 jobs via the munchbox-service pack (one concern per service),   |
|  41 raw .nomad.hcl (system jobs, multi-task groups, weird drivers). |
|                                                                     |
|  Every pack job gets uniformly: Vault wiring, Traefik tags via the  |
|  consulcatalog provider, health checks, Consul registration,        |
|  Prometheus scrape via Consul SD, OTel traces to Tempo, structured  |
|  JSON logs to Loki (via Alloy).                                     |
|                                                                     |
+---------------------------------------------------------------------+
```

**Rule of composition** -- terragrunt provisions, chef configures, nomad
runs. Each layer hands stable identity (Vault PKI, AppRole, JWT) to the
next. None reaches across the boundary directly.

---

## Traffic flow - public service (e.g. `flights.munchbox.cc`)

```
browser
   | HTTPS
Cloudflare edge                          (cert terminated here)
   | tunnel
cloudflared task                         (sidecar inside Traefik alloc on VRRP MASTER)
   | plain HTTP to 127.0.0.1
Traefik :80
   |- cf-tunnel-https@file               sets X-Forwarded-Proto=https
   |- oauth2-proxy-errors@file           401 -> /oauth2/sign_in (renders login page)
   |- oauth2-proxy@file                  forward-auth -> oauth2-proxy.service.consul:4180
   |                                       |- Google OAuth, 3 allowed emails
   |                                       +- injects X-Auth-Request-{User,Email,Token}
   +- consulcatalog routes to flight-fetcher (any nomad client)
                                       |
                                       |- postgres `flight_fetcher` via haproxy-postgres.service.consul:5433 (history)
                                       +- redis via redis.service.consul:6379 (live state)
```

## Traffic flow - LAN-only service (e.g. `consul.munchbox.cc`)

```
browser
   | DNS query
local dnsmasq        on each cluster node (consul::dns recipe)
   | everything not .consul -> 127.0.0.1:5354
CoreDNS              system job on every node
   | forwards to dnsdist first, sequential policy, health-checked, 5min cache
dnsdist              on the ingress VIP (.50:53)
   | leastOutstanding across both Pi-holes
   |   (a failed VIP health check falls straight through to them)
green / logan        Pi-hole + custom dnsmasq.d
   | catalogued *.munchbox.cc names -> 192.168.68.50 (Traefik VIP)
   |   (deny-by-default: only names in the web_services catalog resolve)
ARP
keepalived MASTER    (goren or nomad-client-05)
   | :443 HTTPS, wildcard ACME cert from Let's Encrypt via Cloudflare DNS-01
Traefik
   |- dashboard-allowlan      enforces src in 192.168.68.0/24 + 10.200.0.0/24
   +- consulcatalog -> consul UI on each node's local agent :8500
```

External hits to `*.munchbox.cc` over the CF tunnel can't satisfy
`dashboard-allowlan`, so they 403 -- that's the LAN-only enforcement.

---

## Security spine

**mTLS everywhere.** Every consul <-> nomad <-> vault <-> docker handshake
is mutual-TLS. The PKI tree:

- Munchbox internal root + intermediate (cookbook-shipped) -- primary trust
- Vault PKI intermediate (`pki_int` mount) -- issues consul-server,
  consul-client, nomad-server, nomad-client, vault-server, traefik,
  postgres certs
- `vault_cert_manager` daemon renews certs in-place; on change it reloads
  consul (`systemctl reload`), restarts nomad, reloads vault via SIGHUP
  (**never** restart Vault -- shamir-sealed, would require manual unseal)

**Auth axes**

| Surface | Mechanism |
|---|---|
| SSH (human + cinc-client + ci) | Vault SSH CA, host CA + short-lived user certs (8h `client-user`, 24h `client-service`) |
| Chef -> Vault | AppRole; per-node `role_id` + `secret_id` in encrypted data bag, token sink at `/run/vault-agent/token` |
| Nomad jobs -> Vault | Workload identity (JWT) via `jwt-nomad` backend. The default `nomad-workloads` role carries a templated policy resolving `secret/data/<job id>` from the token's entity alias, so a job reaches only its own prefix with no per-job config. Reading another job's secret needs a `workload_extra_secrets` entry and a role bound on `nomad_job_id` |
| Humans -> public services | Google OAuth via oauth2-proxy forward-auth (3 allowed emails) |
| External ingress | Cloudflare tunnel -- no inbound NAT rules |
| Internal service ACLs | Consul ACL default-deny + Nomad ACLs; per-service tokens in Vault |
| Vulnerability scanning | Trivy server + Temporal scan-worker enumerates running images, stores CVEs in Postgres, dashboard reads the replica |

---

## HA + state

| Concern | Replication | Failover |
|---|---|---|
| Ingress (Traefik + cloudflared + oauth2-proxy) | 2 (goren + nc05) | keepalived VRRP, prio 95 |
| Consul / Nomad / Vault servers | 3 (goren + stabler + nomad-server-03) | Raft, `bootstrap_expect=3` |
| Patroni Postgres | 2 (stabler + nc05) | Patroni leader election, HAProxy reads `/primary` |
| Redis | 2 + Sentinel (bare metal) | Sentinel CONFIG REWRITE, HAProxy reads role |
| Pi-hole DNS | 2 (green + logan) | dnsdist on the ingress VIP (leastOutstanding) for both LAN clients and cluster nodes; the per-node CoreDNS lists the Pi-holes behind dnsdist so a failed VIP falls straight through |
| Recursive DNS | 1 per Pi-hole (unbound on each) | independent -- no shared state |

**Acknowledged single points of failure**

- Loki + Tempo pinned to `nomad-client-02` (single host volume)
- Temporal-server pinned to `nomad-client-03` (single replica, NFS-bound)
- Docker registry pinned to `stabler` (NFS-backed)
- `cinc-server` is single-VM on `rubirosa`
- VRRP ingress pool is 2 nodes; lose both -> no Traefik

---

## Data tiers

| Tier | Service | Storage |
|---|---|---|
| Object (blob) | s3-orchestrator -- 13 backends | OCI / R2 / IBM / e2 / GCS / B2 / Tigris / Supabase / C2 / 2x MinIO / g3-proxy / aptly |
| SQL | Patroni PG18 (15+ app DBs auto-created) | Host volume `/opt/nomad/data/patroni-${ALLOC_INDEX}` |
| K/V cache | Redis + Sentinel | Host volume on bare metal nodes |
| Container images | Docker registry v2 | NFS `/mnt/gdrive/munchbox-data/registry` |
| Apt repo | aptly | s3-orchestrator `aptly` bucket + NFS metadata |
| Media (read-heavy) | Jellyfin / *arr / Deluge | `/tank` SSD on nomad-client-04 |
| Time-series | Prometheus | Host volume |
| Logs | Loki | Host volume on nc02 |
| Traces | Tempo | Host volume on nc02 |
| Secrets | Vault | Consul-backed storage |
| ACME certs | Traefik | Per-ingress-node host volume (independent) |

---

## Backup + scheduled ops (Temporal)

```
Daily 1 AM PT   ->  backup workflow      Nomad + Consul Raft snapshots, pg_dumpall,
                                         registry tarball -> /mnt/gdrive (7d local) +
                                         S3 via s3-orchestrator (30d)

Daily 3 AM PT   ->  trivy scan workflow  every running image via Nomad API -> trivy-server,
                                         results in postgres `trivy`

Daily 5 AM PT   ->  cleanup workflow     SSH each Nomad client, remove orphan alloc dirs
                                         older than 7d grace

Weekly Sun 2 AM ->  registry GC workflow scale registry to 0, run garbage-collect,
                                         scale back (saga-style with deferred cleanup)
```

All workflows emit OTel traces, structured logs, and SDK metrics.

---

## Observability

```
Every node             Prometheus               Grafana
---------------        --------------           --------
coredns         --+    | Consul SD              | + Loki
alloy (logs +    |--->-| scrapes every          | + Tempo (service graph)
  host metrics)  |     | exporter + tagged      | + Postgres
                 |     | service                |   15+ dashboards
                 |     +--> alert_rules.yml     |
                 |          -> AlertManager     |
                 |             -> stabler webhook
                 |                (force-restart sick Nomad jobs)
                 |
                 v
              Loki  (nc02 host vol)
              Tempo (nc02 host vol)  <- apps OTLP gRPC to tempo.service.consul:4317
```

**Probe-shaped checks** go through `blackbox-exporter-external` (oracle) for
public URLs and `blackbox-exporter-internal` (on-prem) for LAN-only
probes. Cloudflare firewall events ship via `cloudflare-log-collector` ->
Loki + Tempo.

---

## Repo layout

```
munchbox/
+- README.md                          <- this file (project overview)
+- CLAUDE.md                          <- repo-wide conventions for AI assistants
+- munchbox-env.sh                    <- source first; exports vault/nomad/consul creds + TF_VARs
+- assets/                            <- repo images (logo, terragrunt pug)
+- scripts/                           <- operator helpers (ssh-cert-login, warp toggles, ...)
|
+- infrastructure/
|  +- cinc/                           <- Cinc cookbooks + roles
|  |  +- README.md                    <- cookbook anatomy, ops, layout
|  |  +- STYLE_GUIDE.md               <- Ruby/Chef style + testing
|  |  +- cookbooks/                   <- 16 cookbooks
|  |  +- roles/                       <- 17 shared fleet roles
|  |  +- nodes/                       <- per-node objects (run_list + tags + attr overrides)
|  |
|  +- terragrunt/                     <- Terraform + Terragrunt
|  |  +- README.md                    <- module/leaf anatomy, ops
|  |  +- STYLE_GUIDE.md               <- HCL style + testing
|  |  +- root.hcl                     <- centralized config + remote_state
|  |  +- _env_helpers/                <- bridge root.hcl locals -> module inputs
|  |  +- modules/                     <- 43 modules
|  |  +- global/                      <- provider-agnostic leaves (secrets, ACLs, app-config)
|  |  +- oci/ kms/ networking/ munchbox-vms/  <- provisioning leaves
|  |  +- dns/ postgres/ s3-orchestrator/      <- service leaves
|  |  +- terratest/                   <- Go integration tests
|  |
|  +- scripts/                        <- bootstrap helpers (fix-vault, oracle-arm-retry)
|
+- nomad/
|  +- jobs/
|  |  +- README.md                    <- pack vs raw, deploying, traefik/vault/placement
|  |  +- STYLE_GUIDE.md               <- Nomad job style + testing
|  |  +- infrastructure/              <- 29 jobs: traefik, patroni, dnsdist, vault-ui, ...
|  |  +- monitoring/                  <- 9 jobs: prom, grafana, blackbox, exporters
|  |  +- media/                       <- 10 jobs: jellyfin, *arr stack, deluge
|  |  +- web/                         <- 10 jobs: dashboards + UI fronts
|  |  +- temporal-workflows/          <- 3 jobs: backup / scan / cleanup workers
|  |  +- logging/                     <- 3 jobs: loki + alloy + tempo
|  |  +- games/                       <- 2 jobs
|  |  +- deprecated/                  <- parked specs (kept for revival, not running)
|  |
|  +- packs/registry/munchbox-service/   <- the shared service pack
|  +- shared.vars.hcl                 <- pihole IPs (used by raw jobs)
|  +- Makefile                        <- make run JOB=<name>
|
+- docker/                            <- container images we build + push to registry.munchbox.cc
|  +- README.md                       <- anatomy, common ops
|  +- STYLE_GUIDE.md                  <- Dockerfile + Makefile conventions
|  +- patroni/                        <- PG18 + Patroni 4.0.4 (used by patroni nomad job)
|  +- ops-build-image/                <- CI toolchain (used by forgejo-runner)
|
+- src/                               <- operator-built apps shipped as containers
   +- vault-cert-manager/             <- Vault PKI cert lifecycle manager (submodule)
   +- trivy-dashboard/                <- vuln dashboard UI
   +- dashboard/                      <- Hugo-based homepage at dashboard.munchbox.cc
   +- personal-site/                  <- alexfreidah.com
   +- phlebotomy-game/ theme-server/  <- smaller bespoke apps
```

These projects graduated to their own repos and are no longer vendored here --
clone them alongside munchbox rather than looking under `src/`:
`s3-orchestrator`, `cloudflare-log-collector`, `oracle-watchdog`,
`nomad-temporal-jobs`, `resume`.

> **For per-area conventions, jump to the README and STYLE_GUIDE next to the
> code.** This file stays at the architectural / cluster level.

---

## Getting started

### Workstation prerequisites

- `vault`, `consul`, `nomad`, `terragrunt`, `terraform`, `nomad-pack` CLIs
- `gh`, `jq`, `python3`
- A WireGuard tunnel to the home LAN (for off-LAN ops)
- Cinc-workstation if you'll touch cookbooks (`make tools` from any cookbook dir)

### Source the env

Every CLI op needs the env vars from Vault. Always start with:

```bash
source munchbox-env.sh
```

This exports `VAULT_ADDR`, `VAULT_TOKEN`, `NOMAD_ADDR`, `NOMAD_TOKEN`,
`CONSUL_HTTP_ADDR`, `CONSUL_HTTP_TOKEN`, plus `TF_VAR_*` secrets for
terraform/terragrunt.

### Deploy a Nomad job

```bash
cd nomad
make plan JOB=<name>      # diff
make run  JOB=<name>      # submit
make stop JOB=<name>      # graceful stop, keep spec
```

`JOB=<name>` is the directory name under `nomad/jobs/<category>/<name>/`,
without path or extension.

### Apply infrastructure

```bash
cd infrastructure/terragrunt/<leaf>
terragrunt init
terragrunt plan
terragrunt apply
```

State lives in Consul at `terraform/munchbox/<provider>/<node_name>`. Each
leaf has isolated state.

### Add a node

1. Add VM entry under `root.hcl` -> `proxmox_vm_groups.<group>.<hostname>`
2. `cd infrastructure/terragrunt/proxmox/<group> && terragrunt apply` -- VM
   provisions
3. Create the per-node Chef node object at `infrastructure/cinc/nodes/<host>.json`
4. Run `infrastructure/scripts/prepare-chef-bootstrap.sh <host>` from
   the workstation -- mints AppRole secret, uploads vault_agent data bag,
   uploads per-node role
5. Run `infrastructure/scripts/bootstrap-cinc-node.sh <host>` to
   install cinc-client + trigger first converge

The node joins Consul + Nomad automatically once converged.

---

## Architectural strengths + tensions

**Strengths the code expresses**

- Single source of truth per concern. Vault paths in one terragrunt list.
  VMs in one root.hcl map. SSH CA in two Vault mounts. PKI in one. Adding
  a service is a small diff at every layer.
- The munchbox-service pack standardizes every Nomad job's shape (Vault
  wiring, Traefik tags, health checks, Prometheus scrape, OTel) so new
  workloads slot into the observability + ingress + auth machinery for
  free.
- Layered fallback at every tier. CoreDNS forwards to dnsdist, which spreads
  across both Pi-holes, and lists the Pi-holes behind it so a failed VIP
  health check falls straight through; dnsmasq has them as upstreams too.
  HAProxy reads Patroni REST in real time. Each Pi-hole has its own
  unbound. s3-orchestrator has per-backend circuit breakers.

**Tensions worth flagging**

- The ingress pair is a 2-host SPoF (goren + nc05).
- Loki + Tempo pinned to nc02 -- a single-host outage kills observability.
- Temporal-server is pinned to nc03; the haproxy-postgres path is bypassed
  via a hardcoded goren IP because Temporal can't handle the multi-IP DNS
  answer.
- The Pi-hole local-fork provider submodule is technical debt (issue
  [#123](https://github.com/afreidah/munchbox/issues/123) tracks
  consolidating onto dklesev).
- Adding a Vault path or DNS record means a terragrunt apply *and* a
  nomad redeploy -- tracked under the deploy-simplification issue.

---

## License

**All Rights Reserved** -- personal homelab project. Code is provided for
educational and reference purposes only.

## Maintainer

Alex Freidah -- alex.freidah@gmail.com
