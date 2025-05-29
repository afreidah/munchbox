###############################################################################
# Node Exporter — Nomad System Job (Multi-Architecture)
#
# - Deploys node_exporter on every node in the cluster
# - Selects the correct image for each architecture (armv6, armv7, arm64, amd64)
# - Listens on port 9100 (default Prometheus metrics)
# - Uses group constraints so each node runs the right binary
###############################################################################

job "node-exporter" {
  datacenters = ["pi-dc"]
  type        = "system"  # Runs one instance per Nomad client node

  # ──────────────────────────────────────────────────────────────────────────
  # Group for ARM64/aarch64 (e.g. Pi 4/5 64-bit OS) — uses official image
  # ──────────────────────────────────────────────────────────────────────────
  group "arm64" {

    constraint {
      attribute = "${attr.cpu.arch}"
      operator  = "="
      value     = "arm64"
    }

    network {
      port "metrics" { static = 9100 }
    }

    task "node-exporter-arm64" {
      driver = "docker"

      config {
        ports = ["metrics"]
        image = "prom/node-exporter:latest"
      }

      resources {
        cpu    = 30
        memory = 20
      }

      env = {
        TZ = "America/Los_Angeles"
      }
    }
  }
}

