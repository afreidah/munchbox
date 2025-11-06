# -------------------------------------------------------------------------------
#  Prometheus Node Exporter — System Metrics Collection Service
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Runs node_exporter on every cluster node via system job, exposing CPU,
#  memory, disk, network, and system metrics on port 9100. Uses host networking
#  for direct port binding and Consul service discovery for dynamic Prometheus
#  scrape target registration.
# -------------------------------------------------------------------------------

job "node-exporter" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "all"

  # --- Job metadata ---
  meta {
    version     = "1.8.2"
    updated     = "2025-10-11"
    description = "Prometheus Node Exporter - System metrics collection"
  }

  # ---------------------------------------------------------------------------
  #  Node Exporter Group
  # ---------------------------------------------------------------------------

  group "prometheus_node_exporter" {

    # --- Network configuration ---
    network {
      mode = "host"
      port "http" {
        static = 9100
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 10
      interval = "5m"
      delay    = "5s"
      mode     = "delay"
    }

    # --- Rolling update strategy ---
    update {
      max_parallel     = 2
      min_healthy_time = "10s"
      healthy_deadline = "2m"
      auto_revert      = true
    }

    # -----------------------------------------------------------------------
    #  Node Exporter Task
    # -----------------------------------------------------------------------

    task "prometheus_node_exporter" {
      driver = "docker"

      # --- Docker image configuration ---
      # Container shares host network namespace for direct port binding
      # Host PID namespace access provides better metrics collection
      config {
        image        = "quay.io/prometheus/node-exporter:v1.8.2"
        network_mode = "host"
        pid_mode     = "host"

        # --- Node exporter command configuration ---
        # Enable useful collectors: processes for system process monitoring
        # Disable noisy collectors: wifi (not applicable to servers), hwmon (noisy on headless systems)
        # Filesystem exclusions: virtual/temporary filesystems with proper regex escaping
        # Mount point exclusions: /dev, /proc, /sys, Docker runtime, ephemeral mounts, /mnt/gdrive
        args = [
          "--path.rootfs=/host",
          "--web.listen-address=0.0.0.0:9100",
          "--web.telemetry-path=/metrics",
          "--collector.processes",
          "--no-collector.wifi",
          "--no-collector.hwmon",
          "--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs|fuse\\.sshfs|tmpfs)$",
          "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|run/.+|mnt/gdrive)($|/)"
        ]

        # --- Volume mounts ---
        # Mount entire host filesystem read-only with recursive slave mode for metric collection
        volumes = [
          "/:/host:ro,rslave"
        ]
      }

      # --- Service registration ---
      service {
        name         = "prometheus-node-exporter"
        port         = "http"
        provider     = "consul"
        address_mode = "host"
        tags = [
          "monitoring",
          "node-exporter",
          "metrics",
          "system"
        ]

        # --- Primary health check ---
        check {
          name     = "node-exporter-alive"
          type     = "http"
          method   = "GET"
          path     = "/metrics"
          port     = "http"
          interval = "15s"
          timeout  = "3s"
          check_restart {
            limit = 3
            grace = "10s"
          }
        }

        # --- Secondary health check ---
        check {
          name     = "node-exporter-metrics"
          type     = "http"
          method   = "GET"
          path     = "/metrics"
          port     = "http"
          interval = "60s"
          timeout  = "5s"
          header {
            Accept = ["text/plain"]
          }
        }
      }

      # --- Runtime environment ---
      env {
        TZ                               = "America/Los_Angeles"
        NODE_EXPORTER_WEB_TELEMETRY_PATH = "/metrics"
      }

      # --- Resource allocation ---
      # Lightweight allocation suitable for system service running on all nodes
      resources {
        cpu    = 150
        memory = 64
      }

      # --- Termination configuration ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
