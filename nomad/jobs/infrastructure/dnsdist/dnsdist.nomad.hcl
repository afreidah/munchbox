# -------------------------------------------------------------------------------
# dnsdist - LAN DNS Load Balancer (front of the Pi-holes)
#
# Project: Munchbox / Author: Alex Freidah
#
# Single HA DNS endpoint for non-Nomad LAN clients (laptops/TVs/phones).
# Runs on both ingress nodes (active-passive behind the existing keepalived
# VIP), binds the DNS VIP on :53 (UDP+TCP), and:
#   - routes *.consul -> the node's local Consul agent (127.0.0.1:8600)
#   - load-balances everything else across the two Pi-holes (leastOutstanding)
#
# This bypasses the per-node CoreDNS path on purpose: LAN endpoints only need
# *.munchbox.cc + public (which the Pi-holes already serve) plus the occasional
# .consul name (handled here via the local agent). CoreDNS stays untouched for
# in-cluster container/node resolution.
#
# Why dnsdist and not two nameservers in resolv.conf: glibc only fails over to
# the 2nd nameserver on timeout, so two Pi-holes = #1 gets ~all queries. dnsdist
# gives real load balancing, DNS-aware health checks, and Prometheus metrics.
#
# PREREQS (not created by this job):
#   - keepalived must own the DNS VIP on the ingress pair (reuse the traefik VIP
#     or a dedicated one -- set var.dns_vip below).
#   - net.ipv4.ip_nonlocal_bind=1 on both ingress nodes (cinc), so the standby
#     dnsdist can bind the VIP before keepalived places it. dnsmasq is pinned to
#     loopback + node-IP (bind-interfaces), so VIP:53 does not collide with it.
#   - secret/dnsdist (console password + apiKey) -- provisioned by the
#     access-keys terragrunt module, NOT a manual vault kv put.
#   - DHCP hands clients the DNS VIP instead of the two Pi-hole IPs.
# -------------------------------------------------------------------------------

# --- Shared Variables (from shared.vars.hcl) ---
variable "pihole_1" {
  type    = string
  default = "192.168.68.62"
}
variable "pihole_2" {
  type    = string
  default = "192.168.68.64"
}

# --- DNS VIP the keepalived ingress pair floats; clients point here. Reuses the
#     traefik VIP by default (dnsdist :53 does not collide with traefik :80/:443). ---
variable "dns_vip" {
  type    = string
  default = "192.168.68.50"
}

job "dnsdist" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"
  priority    = 90

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
    version    = "1.9.9"
    tier       = "tier-0"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
    stagger          = "30s"
  }

  # ---------------------------------------------------------------------------
  # Placement - ingress nodes only (same pair that holds the keepalived VIP)
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  # Task Group: dnsdist
  # ---------------------------------------------------------------------------

  group "dnsdist" {

    # --- Network: host mode so dnsdist can bind the floating VIP directly.
    #     Only the web/metrics port is declared; :53 is bound to the VIP inside
    #     dnsdist (setLocal), deliberately NOT a node-wide :53 reservation. ---
    network {
      mode = "host"
      port "web" {
        static = 8083
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # -----------------------------------------------------------------------
    # Service: dnsdist web (Prometheus /metrics + built-in console)
    # The DNS listener itself is NOT registered -- clients reach it via the
    # VIP, and we do NOT want Traefik/consul-catalog to pick it up.
    # -----------------------------------------------------------------------

    service {
      name     = "dnsdist"
      port     = "web"
      provider = "consul"

      tags = [
        # NOT tagged `metrics`: dnsdist's /metrics needs the apiKey, so the generic
        # (unauthenticated) consul-auto prometheus job would 401 on it. A dedicated
        # `dnsdist` scrape job with basic_auth handles it instead.
        # Console behind OAuth + LAN allowlist on websecure (LAN only), mirroring
        # the other admin UIs. dnsdist serves the console and /metrics on :8083.
        "traefik.enable=true",
        "traefik.http.routers.dns.rule=Host(`dns.munchbox.cc`)",
        "traefik.http.routers.dns.entrypoints=websecure",
        "traefik.http.routers.dns.tls=true",
        "traefik.http.routers.dns.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file,dashboard-allowlan@file,dnsdist-auth@file",
      ]

      # --- TCP, not HTTP /metrics: dnsdist gates /metrics behind the API key,
      #     and a Nomad check can't carry the Vault-stored key. A TCP connect to
      #     the webserver confirms the (single) dnsdist process is alive. ---
      check {
        name     = "dnsdist-listener"
        type     = "tcp"
        port     = "web"
        interval = "15s"
        timeout  = "3s"
      }
    }

    # -----------------------------------------------------------------------
    # Task: dnsdist
    # -----------------------------------------------------------------------

    task "dnsdist" {
      driver = "docker"

      # --- Run as root: dnsdist binds :53 (privileged), and the upstream image
      #     otherwise runs as a non-root user that can't bind low ports. ---
      user = "root"

      # --- Vault Integration (web console password + API key) ---
      vault {
        role        = "nomad-workloads"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      # NOTE: verify/pin the current stable dnsdist tag before deploy.
      config {
        image        = "powerdns/dnsdist-20:2.0.7"
        network_mode = "host"
        args         = ["--supervised", "--disable-syslog", "-C", "/etc/dnsdist/dnsdist.conf"]
        volumes = [
          "local/dnsdist.conf:/etc/dnsdist/dnsdist.conf:ro"
        ]
      }

      # --- dnsdist configuration (Lua) ---
      template {
        destination = "local/dnsdist.conf"
        change_mode = "restart"
        data        = <<EOH
-- ---------------------------------------------------------------------------
-- dnsdist - LAN DNS load balancer (managed by Nomad)
-- ---------------------------------------------------------------------------

-- Who may query us: LAN + Oracle WG ranges + loopback.
setACL({"192.168.68.0/24", "10.200.0.0/24", "127.0.0.0/8"})

-- Bind the floating DNS VIP on :53 (UDP + TCP). Requires ip_nonlocal_bind=1
-- on the host so the standby instance can bind before keepalived moves the VIP.
setLocal("${var.dns_vip}:53")

-- -------------------------------------------------------------------------
-- Backends
-- -------------------------------------------------------------------------

-- Pi-holes: default pool, balanced by fewest in-flight queries. Default health
-- check (a.root-servers.net A) is fine -- the Pi-holes recurse public DNS.
newServer({address="${var.pihole_1}:53", name="pihole-green"})
newServer({address="${var.pihole_2}:53", name="pihole-logan"})
setServerPolicy(leastOutstanding)

-- Local Consul agent for .consul names, in its own pool. The default probe
-- would fail against a consul-only agent, so health-check a real .consul name.
newServer({
  address="127.0.0.1:8600",
  name="consul-agent",
  pool="consul",
  checkName="consul.service.consul",
  checkType="A"
})

-- -------------------------------------------------------------------------
-- Routing: *.consul -> local agent, everything else -> Pi-hole pool
-- -------------------------------------------------------------------------
consul_names = newSuffixMatchNode()
consul_names:add("consul")
addAction(SuffixMatchNodeRule(consul_names), PoolAction("consul"))

-- -------------------------------------------------------------------------
-- Suppress HTTPS/SVCB (type 65) for our own zone.
--
-- Pi-hole rewrites the A record to the ingress VIP but forwards the HTTPS
-- record from Cloudflare untouched, so LAN clients get an answer carrying
-- ipv4hint=<cloudflare edge> plus an ECH config for it -- split-horizon only
-- half applied. Firefox on plain DNS never asks for type 65 so it goes
-- unnoticed, but any resolver that honours the record (Firefox with DoH on,
-- Chrome, curl 8.14+) follows the hint straight out to the edge and picks up
-- its cache instead of the local origin.
--
-- NOERROR with no answer is NODATA: clients fall back to the A record.
-- -------------------------------------------------------------------------
local_names = newSuffixMatchNode()
local_names:add("munchbox.cc")
addAction(
  AndRule({SuffixMatchNodeRule(local_names), QTypeRule(DNSQType.HTTPS)}),
  RCodeAction(DNSRCode.NOERROR)
)

-- -------------------------------------------------------------------------
-- Packet cache -- offloads repeat lookups from the weak armv6 Pi-holes (the
-- whole point of fronting them). Caps at the record's own TTL (maxTTL 1h);
-- staleTTL serves slightly-stale answers if both Pi-holes are briefly down.
-- Trade-off: Pi-hole's per-client stats undercount cache-hit queries.
-- Only the default (Pi-hole) pool is cached; the consul pool stays fresh.
-- -------------------------------------------------------------------------
pc = newPacketCache(100000, {maxTTL=3600, minTTL=0, temporaryFailureTTL=60, staleTTL=60})
getPool(""):setCache(pc)

-- -------------------------------------------------------------------------
-- Web console + Prometheus metrics (/metrics on the same listener)
-- -------------------------------------------------------------------------
-- apiKey (access_key from secret/dnsdist) gates /metrics. NO console password:
-- the UI is already gated by oauth2-proxy + LAN allowlist at Traefik, and a
-- dnsdist Basic-auth 401 would collide with the oauth2-proxy-errors middleware
-- and loop the login. ACL still restricts the listener to LAN sources.
{{ with secret "secret/data/dnsdist" -}}
setWebserverConfig({
  apiKey="{{ .Data.data.access_key }}",
  acl="192.168.68.0/24, 10.200.0.0/24, 127.0.0.0/8"
})
{{- end }}
webserver("0.0.0.0:8083")

-- -------------------------------------------------------------------------
-- Per-query traffic insight (OPTIONAL hook)
-- dnsdist has no OpenTelemetry/OTLP exporter, so it cannot feed Tempo. For
-- full who-asked-what visibility, stream queries via dnstap/protobuf to a
-- receiver and uncomment below once that receiver exists:
--   fsl = newFrameStreamTcpLogger("<dnstap-receiver>:6000")
--   addAction(AllRule(), DnstapLogAction("dnsdist", fsl))
--   addResponseAction(AllRule(), DnstapLogResponseAction("dnsdist", fsl))
-- -------------------------------------------------------------------------
EOH
      }

      # --- Resources (dnsdist is light; it's a proxy, the Pi-holes do the work) ---
      resources {
        cpu        = 200
        memory     = 128
        memory_max = 256
      }

      # --- Termination ---
      kill_timeout = "15s"
      kill_signal  = "SIGTERM"
    }
  }
}
