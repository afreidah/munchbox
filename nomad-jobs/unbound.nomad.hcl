# -------------------------------------------------------------------------------
# Unbound DNS Resolver — Nomad service job
#
# - Runs the Unbound validating, recursive, caching DNS resolver.
# - Uses the official mvance/unbound image.
# - Persists configuration on the host.
# - Exposes DNS on port 5335 (host) mapped to 53 (container).
# - Registers service with Consul for discovery and health checks.
# -------------------------------------------------------------------------------

job "unbound" {
  datacenters = ["dc1"]   # --- Nomad datacenter(s) to run in ---
  type        = "service" # --- Service job type ---

  meta {
    run_uuid = "${uuidv4()}" # --- Unique run identifier ---
  }

  group "unbound" {
    network {
      mode = "host" # --- Use host networking for container ---
      port "dns" {
        static = 5335 # --- Expose DNS on port 5335 (host) ---
        to     = 53   # --- Map to port 53 (container) ---
      }
    }

    volume "unbound_data" {
      type      = "host"
      source    = "unbound_data"   # --- Already defined in your client config ---
      read_only = false
    }

    task "unbound" {
      driver = "docker" # --- Use Docker driver ---

      config {
        image              = "mvance/unbound:latest" # --- Unbound Docker image ---
        image_pull_timeout = "10m"                   # --- Timeout for pulling image ---
        network_mode       = "host"                  # --- Host networking for container ---
      }

      env {
        TZ = "UTC" # --- Timezone ---
      }

      # -------------------------------------------------------------------------
      # Mount the host volume where Unbound expects its files
      # -------------------------------------------------------------------------
      volume_mount {
        volume      = "unbound_data"
        destination = "/etc/unbound" # --- Default path used by image ---
        read_only   = false
      }

      # -------------------------------------------------------------------------
      # Write unbound.conf directly into that mounted dir
      # -------------------------------------------------------------------------
      template {
        destination = "/opt/unbound/unbound.conf"
        perms       = "0644"
        change_mode = "noop"

        data = <<EOU
server:
  interface: 0.0.0.0
  port: 53

  do-ip4: yes
  do-udp: yes
  do-tcp: yes

  access-control: 127.0.0.0/8 allow
  access-control: 192.168.0.0/16 allow
  access-control: 10.0.0.0/8      allow

  root-hints: "/opt/unbound/root.hints"
  auto-trust-anchor-file: "/opt/unbound/root.key"

  cache-min-ttl: 3600
  cache-max-ttl: 86400
  prefetch: yes

  hide-identity: yes
  hide-version:  yes
  harden-glue:   yes
  harden-dnssec-stripped: yes
  rrset-roundrobin: yes
  so-reuseport: yes
  aggressive-nsec: yes

remote-control:
  control-enable: no
EOU
      }

      service {
        name     = "unbound"   # --- Service name for Consul ---
        provider = "consul"    # --- Register with Consul ---
        port     = "dns"       # --- Service port ---

        check {
          name     = "unbound-tcp" # --- Health check name ---
          type     = "tcp"         # --- TCP health check ---
          port     = "dns"         # --- Port to check ---
          interval = "10s"         # --- Check interval ---
          timeout  = "2s"          # --- Timeout for check ---
        }
      }
    }
  }
}
