# Home Nomad Cluster – Architecture & Build Plan

## 1. Goals
- Provide a resilient home + personal-use Nomad cluster for learning and running services.
- Nomad-first: run everything as Nomad jobs unless bare metal is clearly better.
- Single ingress with fast L2 failover; all admin UIs are LAN/VPN-only.
- Service discovery via Consul; recursive DNS + filtering via Pi-hole + Unbound.
- GitHub Actions CI/CD with self-hosted (Nomad) runners; static secrets now, OpenBao later.
- Practical storage on Lenovo NVMe + 2TB USB; simple, consistent backups.

---

## 2. Hardware Inventory & Roles

| Node | Specs | Roles |
|------|------|-------|
| **Lenovo ThinkCentre M910q** | i5-6500T, 16GB, 256GB NVMe | Nomad+Consul server, **primary Traefik**, Keepalived MASTER, PIA ingress WG, registry, metrics/logs, CI runners, NFS server, Chef Server (bare metal 7443) |
| **Raspberry Pi 5 #1 (4GB)** | ARM64 | Nomad+Consul server, **shadow Traefik**, Keepalived BACKUP, standby PIA, general workloads |
| **Raspberry Pi 5 #2 (4GB)** | ARM64 | Nomad+Consul server, general workloads |
| **iMac (2GB)** | x86_64 | Nomad client, **OpenBao**, Nextcloud app (optional) |
| **Pi 1 #1 (512MB)** | ARMv6 | **Pi-hole + Unbound** (primary), Consul agent |
| **Pi 1 #2 (512MB)** | ARMv6 | **Pi-hole + Unbound** (secondary), Consul agent |
| **External 2TB USB** | USB 3 | Primary data/backup on Lenovo |
| **Old HDDs** | Mixed | **Cold/offline backup rotation** (not live) |

Quorum: 3× Consul servers (Lenovo + both Pi 5s), 3× Nomad servers (same trio).

---

## 3. Networking, Ingress, DNS, Certs

- **Flat L2** for now (VLANs later).
- **Ingress path**: **PIA WireGuard static IP → DNAT → VIP:443/80 → Traefik**.
- **Failover**: Keepalived VRRP VIP on Lenovo (MASTER) + Pi5 #1 (BACKUP).
- **Traefik**: runs on Lenovo + Pi5 #1; binds VIP :80/:443.
- **Cloudflare DNS**: `edge.yourdomain.com` → PIA IP; `*.apps.yourdomain.com` → `edge`.
- **ACME**: DNS-01 (Cloudflare) wildcard certs.
- **Admin access**: LAN/VPN-only via Traefik **internal** entrypoint (+ IP allowlist).

**Internal DNS (authoritative for your LAN):**
- **Pi-hole (+ Unbound)** on both Pi 1s for all clients.
- **Conditional forward** `.consul` → Consul servers (UDP/TCP 8600).
- **Local DNS overrides** in Pi-hole: `edge.yourdomain.com` + `*.apps.yourdomain.com` → LAN VIP.

---

## 4. What Runs Where (Nomad vs Bare Metal)

**Bare metal**
- Keepalived (VRRP VIP) on Lenovo + Pi5 #1
- PIA WireGuard (ingress) on Lenovo + Pi5 #1
- Consul & Nomad **servers** (Lenovo + both Pi5s)
- Pi-hole + Unbound on Pi 1s
- NFS server (Lenovo) & client mount (iMac)
- **Chef Server (Cinc)** on Lenovo, bound to `127.0.0.1:7443`, behind Traefik internal

**Nomad jobs**
- **Traefik** (Lenovo + Pi5 #1), host networking
- **OpenBao** (iMac), integrated Raft; snapshots to Lenovo
- **Nextcloud** (either iMac w/ NFS data, or Lenovo), Redis+DB co-located
- **Deluge + VPN sidecar** (Lenovo), WebUI internal-only
- **Registry + UI** (Lenovo)
- **Observability** (Lenovo): vmagent → VictoriaMetrics, vmalert, Alertmanager, Loki, Grafana
- **node_exporter / blackbox_exporter** (system jobs) on Lenovo + Pi5s + iMac
- **Vector/Fluent Bit** (system jobs) on Lenovo + Pi5s + iMac
- **Self-hosted GitHub runners** (Lenovo amd64; Pi5s arm64), ephemeral

---

## 5. Storage & Backups

**Mounts**
- **Lenovo NVMe**: live DBs/caches, registry index
- **Lenovo 2TB USB** (`/srv/data`): backups, registry blobs, metrics, logs, Nextcloud data (if hosted here)
- **NFS**: Lenovo exports `/srv/data/nextcloud/data` to iMac when Nextcloud runs there

**Backups (Nomad jobs / cron)**
- **OpenBao** snapshots → `/srv/data/backups/openbao/`
- **Chef Server**: `chef-server-ctl backup` → `/srv/data/backups/chef-server/`
- **Nextcloud**: DB dump + config tar + restic snapshot of data
- **Nomad job specs/configs**
- **Old HDDs** used for **offline rotation**; monthly **restore drills**

---

## 6. Logging, Rotation, Monitoring, Alerts

**Central logs**: Vector/Fluent Bit → **Loki** (Lenovo), 7–14d retention  
**Local rotation**:
- journald caps: Lenovo/Pi5/iMac **200MB** (iMac ok at 100MB), Pi1 **50MB**
- Docker logs: `max-size=10m`, `max-file=3`
- Service logrotate (e.g., Pi-hole)

**Metrics & Alerts**:
- vmagent → VictoriaMetrics + vmalert + Alertmanager
- Exporters: node_exporter on all but Pi1s; Traefik metrics
- Alerts: disk 80/90%, CPU/mem pressure, Traefik `/ping`, PIA up, Consul/Nomad health, Pi-hole UI, cert expiry, OpenBao snapshot age, Nextcloud cron, Loki/VM ingestion

---

## 7. Security Baseline

- Admin UIs only on **Traefik internal** entrypoint (+ IP allowlist for LAN/VPN CIDRs).
- **Nomad & Consul ACLs** on; least-priv tokens for CI.
- Secrets: **GitHub Actions secrets** now; migrate to **OpenBao OIDC** later.
- SSH keys only; disable passwords.
- Regular OS updates; image scanning (Trivy/Grype).

---

## 8. CI/CD (Phase 1 – GitHub Actions Secrets)

**Create these GitHub Secrets**
- Core: `NOMAD_ADDR`, `NOMAD_TOKEN`, `REGISTRY_URL`, `REGISTRY_USER`, `REGISTRY_PASS`
- Chef: `CHEF_SERVER_URL`, `CHEF_USER`, `CHEF_CLIENT_KEY`
- Terraform/Terragrunt (optional): `CONSUL_HTTP_ADDR`, `CONSUL_HTTP_TOKEN`

**Runner topology**
- Lenovo: 1–2 amd64 runners; Pi5s: 1 arm64 each (all **ephemeral**)
- Labels: `self-hosted`, `nomad`, `amd64` or `arm64`

**Example workflows (snippets)**

_Chef PR checks_
```yaml
name: chef-ci
on: { pull_request: { paths: ['cookbooks/**'] } }
jobs:
  lint-spec:
    runs-on: [self-hosted, nomad, amd64]
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: '3.2', bundler-cache: true }
      - run: bundle install --without kitchen
      - run: bundle exec cookstyle
      - run: bundle exec rspec --format progress
```

_Chef deploy (main, env approval)_
```yaml
name: chef-deploy
on:
  push: { branches: [main], paths: ['cookbooks/**'] }
  workflow_dispatch: {}
jobs:
  package:
    runs-on: [self-hosted, nomad, amd64]
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: '3.2', bundler-cache: true }
      - run: |
          cd cookbooks/my_cookbook
          chef install Policyfile.rb
          chef export Policyfile.rb ./pkg --force
      - uses: actions/upload-artifact@v4
        with: { name: policy-export, path: cookbooks/my_cookbook/pkg }
  deploy:
    needs: package
    runs-on: [self-hosted, nomad, amd64]
    environment: { name: production, url: ${{ secrets.CHEF_SERVER_URL }} }
    steps:
      - uses: actions/download-artifact@v4
        with: { name: policy-export, path: ./pkg }
      - name: Push policy to Cinc Server
        env:
          CHEF_SERVER_URL: ${{ secrets.CHEF_SERVER_URL }}
          CHEF_USER:       ${{ secrets.CHEF_USER }}
          CHEF_CLIENT_KEY: ${{ secrets.CHEF_CLIENT_KEY }}
        run: |
          printf '%s' "$CHEF_CLIENT_KEY" > client.pem
          export CHEF_LICENSE=accept
          chef push home ./pkg
          chef policy apply home my_cookbook production
```

_Docker build & deploy_
```yaml
name: docker-pipeline
on:
  pull_request: { paths: ['**/Dockerfile','src/**'] }
  push: { branches: [main] }
jobs:
  build-pr:
    runs-on: [self-hosted, nomad, amd64]
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ${{ secrets.REGISTRY_URL }}
          username: ${{ secrets.REGISTRY_USER }}
          password: ${{ secrets.REGISTRY_PASS }}
      - run: |
          IMAGE=${{ secrets.REGISTRY_URL }}/myapp
          TAG=pr-${{ github.event.number }}
          docker buildx build --platform linux/amd64,linux/arm64 -t $IMAGE:$TAG --push .
  deploy-main:
    if: github.ref == 'refs/heads/main'
    runs-on: [self-hosted, nomad, amd64]
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ${{ secrets.REGISTRY_URL }}
          username: ${{ secrets.REGISTRY_USER }}
          password: ${{ secrets.REGISTRY_PASS }}
      - run: |
          IMAGE=${{ secrets.REGISTRY_URL }}/myapp
          SHA=${GITHUB_SHA::7}
          docker buildx build --platform linux/amd64,linux/arm64             -t $IMAGE:$SHA -t $IMAGE:latest --push .
          nomad job run -var image=$IMAGE jobs/myapp.nomad
```

---

## 9. Dynamic Storage Strategy

**Phase 1 (now):**  
- **Host/NFS bind mounts** for stateful data (Chef provisions dirs).  
- Per-task **`ephemeral_disk`** for scratch/caches.

_Examples_
```hcl
volume "appdata" { type = "host"; source = "/srv/data/app" }

task "svc" {
  volume_mount { volume = "appdata"; destination = "/var/lib/app"; read_only = false }
  ephemeral_disk { size = 1024 } # MB
}
```

**Phase 2 (optional later):**  
- Add **CSI** if you need PVC-like dynamic volumes:
  - **democratic-csi (NFS)** for RWX “give me 20Gi” style volumes.
  - Keep write-heavy raft/DB data on **local disks**; back them up to NFS.

_Guardrails_: pin stateful jobs; don’t put raft/DB on NFS; set disk alerts; prune images/registries regularly.

---

## 10. Hardware Baseline

- **UPS** for Lenovo, 2TB USB, router/switch, both Pi-holes.
- **Spare SDs/PSUs/USB NICs** for Pis; powered USB hub if needed.
- **Cooling** for Pi5s; dust clean Lenovo/iMac.
- **Smart plugs** for remote reboots.

---

## 11. Chef Server (Cinc) Behind Traefik

- Chef Server runs **bare metal** on Lenovo; Nginx bound to `127.0.0.1:7443`.
- Traefik **internal** route `chef.int.yourdomain.com` → `127.0.0.1:7443`.
- Backups: nightly `chef-server-ctl backup` → `/srv/data/backups/chef-server/`.

---

## 12. OpenBao (Secrets)

- Nomad job on **iMac**; 256–512MB RAM; **local disk** for Raft.
- **Nightly snapshots** to Lenovo `/srv/data/backups/openbao/`.
- LAN/VPN-only; audit logs shipped to Loki (rotated).
- Upgrade path: **GitHub OIDC → OpenBao JWT auth** for ephemeral CI secrets.

---

## 13. Ephemeral GitHub Actions Runner (Nomad Job Skeleton)

```hcl
job "gha-runner-ephemeral" {
  type        = "service"
  datacenters = ["dc1"]

  variable "runner_count"   { type = number  default = 1 }
  variable "runner_labels"  { type = list(string) default = ["self-hosted","nomad","amd64"] }
  variable "github_scope_url" { type = string }
  variable "arch"           { type = string default = "amd64" }

  group "runner" {
    count = var.runner_count

    constraint { attribute = "${attr.cpu.arch}"; value = var.arch }
    network { mode = "bridge" }

    task "docker-daemon" {
      driver = "docker"
      config { image = "docker:24-dind"; privileged = true; args = ["--mtu=1450"] }
      resources { cpu = 300; memory = 384 }
    }

    task "runner" {
      driver = "docker"
      config {
        image = "ghcr.io/myoung34/github-runner:latest"
        env = {
          DOCKER_HOST      = "tcp://127.0.0.1:2375"
          REPO_URL         = "${NOMAD_VAR_github_scope_url}"
          ORG_URL          = ""
          RUNNER_EPHEMERAL = "true"
          RUNNER_LABELS    = "${join(",", var.runner_labels)}"
        }
      }
      resources { cpu = 800; memory = 1024 }

      template {
        destination = "secrets/env"
        env         = true
        data = <<-EOT
          ACCESS_TOKEN={{ with secret "secrets/github/gha_runner_token" }}{{ .Data.data.token }}{{ end }}
        EOT
      }

      service {
        name = "gha-runner"
        port = "dummy"
        check {
          type     = "script"
          name     = "dind-ready"
          command  = "/bin/sh"
          args     = ["-lc", "nc -z 127.0.0.1 2375"]
          interval = "10s"
          timeout  = "2s"
        }
      }

      kill_timeout = "30s"
    }
  }
}
```

**Usage**
```bash
# store runner token (temporary: PAT with runner-admin scope)
nomad var put -force secrets/github/gha_runner_token token=<PAT>

# amd64 pool on Lenovo
nomad job run -var 'arch=amd64'               -var 'runner_count=2'               -var 'runner_labels=["self-hosted","nomad","amd64","infra"]'               -var 'github_scope_url=https://github.com/<owner>/<repo>'               gha-runner-ephemeral.nomad

# arm64 pool on Pi5
nomad job run -var 'arch=arm64'               -var 'runner_count=1'               -var 'runner_labels=["self-hosted","nomad","arm64"]'               -var 'github_scope_url=https://github.com/<owner>/<repo>'               gha-runner-ephemeral.nomad
```

---

## 14. Rollout Order (High Level)

1) OS + static IPs → Consul servers (3) → Nomad servers (3).  
2) Keepalived + Traefik pair; PIA WG + DNAT failover hooks.  
3) Cloudflare DNS + ACME DNS-01.  
4) Pi-hole + Unbound on Pi1s; DHCP hands out both.  
5) `/srv/data` on Lenovo; NFS export (if Nextcloud on iMac).  
6) Observability stack (VM/Loki/Grafana/AM).  
7) Registry.  
8) Nextcloud (iMac or Lenovo).  
9) OpenBao (iMac).  
10) Deluge + VPN sidecar.  
11) Chef Server (7443 behind Traefik).  
12) CI runners + workflows; (optional) Terraform/Terrateam.  
13) Backups + alert rules; test restores & failover.

---

## 15. Future Expansion

- VLAN segmentation (Infra / LAN / IoT/Guest).  
- CSI (democratic-csi NFS) if you want dynamic volumes.  
- Pi SATA hats as a storage node (backups/cold data).  
- GPU node for media/ML.  
- OpenBao OIDC for ephemeral CI secrets; signed images (Cosign).  
- PR preview deployments (Nomad jobs per PR).
