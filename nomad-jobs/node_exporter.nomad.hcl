# -------------------------------------------------------------------------------
# Node Exporter — Nomad System Job (Multi-Architecture)
#
# - Deploys node_exporter on every node in the cluster
# - Selects the correct image for each architecture (armv6, armv7, arm64, amd64)
# - Listens on port 9100 (default Prometheus metrics)
# - Uses group constraints so each node runs the right binary
# -------------------------------------------------------------------------------

job "node-exporter" {
  datacenters = ["pi-dc"]   # --- Nomad datacenter(s) to run in ---
  type        = "system"    # --- Runs one instance per Nomad client node ---

  # ---------------------------------------------------------------------------
  # Meta data for tracking and identification
  # ---------------------------------------------------------------------------
  meta {
    run_uuid = "${uuidv4()}"
  }

  # ---------------------------------------------------------------------------
  # Group for ARM64/aarch64 (e.g. Pi 4/5 64-bit OS) — uses official image
  # ---------------------------------------------------------------------------
  group "arm64" {

    # --- Constraint to ensure this group runs only on ARM64 nodes ---
    constraint {
      attribute = "${attr.cpu.arch}"
      operator  = "="
      value     = "arm64"
    }

    # --- Attach the host volume for metrics (if needed) ---
    network {
      port "metrics" { static = 9100 }
    }

    # --- Service definition for Consul registration ---
    service {
      name = "node-exporter"
      port = "metrics"
      check {
        type     = "http"
        path     = "/metrics"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # ---------------------------------------------------------------------------
    # Task definition for the ARM64 node_exporter
    # ---------------------------------------------------------------------------
    task "node-exporter-arm64" {
      driver = "docker"

      config {
        ports = ["metrics"]
        image = "prom/node-exporter:v1.7.0"
      }

      resources {
        cpu    = 30   # --- CPU MHz ---
        memory = 20   # --- Memory MB ---
      }

      env = {
        TZ = "America/Los_Angeles"
      }
    }
  }
}
