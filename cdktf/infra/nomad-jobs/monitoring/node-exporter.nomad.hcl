# -------------------------------------------------------------------------------
# Prometheus Node Exporter — Nomad System Job
#
# Purpose:
#   - Run node_exporter on every node via Nomad "system" job
#   - Expose system metrics on port 9100 for Prometheus scraping
#   - Host networking for direct node access
#   - Consul service registration for dynamic discovery
#
# Architecture:
#   - System job = runs on ALL nodes automatically
#   - Host networking = binds directly to node's port 9100
#   - Root filesystem mounted read-only for metric collection
#   - No web UI needed = no Traefik routing required
#
# Metrics Exposed:
#   - CPU usage, load averages
#   - Memory and swap usage
#   - Disk space and I/O statistics
#   - Network interface statistics
#   - System uptime and boot time
#
# Integration:
#   - Discovered by Prometheus via Consul service discovery
#   - No manual configuration needed when adding/removing nodes
#   - Automatically starts on new nodes added to cluster
# -------------------------------------------------------------------------------

job "node-exporter" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "all"    # Deploy to all node pools
  type        = "system" # Runs on every eligible node

  # Job metadata for tracking and management
  meta {
    version     = "1.8.2"
    updated     = "2025-10-11"
    description = "Prometheus Node Exporter - System metrics collection"
  }

  group "prometheus_node_exporter" {
    # System jobs don't specify count - automatically runs everywhere

    # Network configuration - host mode for direct port binding
    network {
      mode = "host" # Direct access to host networking stack

      port "http" {
        static = 9100 # Standard node_exporter port across industry
      }
    }

    # Restart policy - resilient for critical system monitoring
    restart {
      attempts = 10      # More attempts since this is system-critical
      interval = "5m"    # Reset attempt counter every 5 minutes
      delay    = "5s"    # Brief delay between restart attempts
      mode     = "delay" # Use delay mode for gradual backoff
    }

    # Update strategy for system job - careful rolling updates
    update {
      max_parallel     = 2 # Update only 2 nodes at a time
      min_healthy_time = "10s"
      healthy_deadline = "2m"
      auto_revert      = true # Rollback on failure
    }

    task "prometheus_node_exporter" {
      driver = "docker"

      config {
        image = "quay.io/prometheus/node-exporter:v1.8.2"

        # Networking configuration for host access
        network_mode = "host" # Container shares host network namespace
        pid_mode     = "host" # Access to host PID namespace for better metrics

        # Command arguments - configure node_exporter behavior
        args = [
          "--path.rootfs=/host",
          "--web.listen-address=0.0.0.0:9100",
          "--web.telemetry-path=/metrics",

          # Enable useful collectors
          "--collector.processes",

          # Disable noisy/unnecessary collectors for server environment
          "--no-collector.wifi",
          "--no-collector.hwmon",

          # Filesystem collector configuration - use proper regex escaping
          # Exclude virtual/temporary filesystems
          "--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs|fuse\\.sshfs|tmpfs)$",

          # Exclude specific mount points
          "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|run/.+|mnt/gdrive)($|/)",
        ]

        # Volume mounts - mount host filesystem for metric collection
        volumes = [
          "/:/host:ro,rslave" # Read-only recursive mount of entire host FS
        ]
      }

      # Resource allocation - lightweight for system service
      resources {
        cpu    = 150
        memory = 64
      }

      # Consul service registration for Prometheus discovery
      service {
        name         = "prometheus-node-exporter"
        port         = "http"
        provider     = "consul"
        address_mode = "host" # Register the actual node IP, not container IP

        # Service tags - metadata for service discovery
        tags = [
          "monitoring",    # General monitoring service
          "node-exporter", # Specific exporter type
          "metrics",       # Provides metrics endpoint
          "system"         # System-level monitoring
        ]

        # Primary health check - ensure metrics endpoint responds
        check {
          name     = "node-exporter-alive"
          type     = "http"
          method   = "GET"
          path     = "/metrics"
          port     = "http"
          interval = "15s" # Check every 15 seconds
          timeout  = "3s"  # 3 second timeout

          # Restart task if health checks fail consistently
          check_restart {
            limit = 3     # Restart after 3 consecutive failures
            grace = "10s" # 10 second grace period before restart
          }
        }

        # Secondary check - validate metrics content is being produced
        check {
          name     = "node-exporter-metrics"
          type     = "http"
          method   = "GET"
          path     = "/metrics"
          port     = "http"
          interval = "60s" # Less frequent detailed check
          timeout  = "5s"

          # Validate response headers
          header {
            Accept = ["text/plain"] # Prometheus text format
          }
        }
      }

      # Environment variables
      env {
        TZ = "America/Los_Angeles" # Consistent timezone across cluster

        # Node exporter specific environment
        NODE_EXPORTER_WEB_TELEMETRY_PATH = "/metrics"
      }

      # Lifecycle management
      kill_timeout = "30s"     # Allow graceful shutdown
      kill_signal  = "SIGTERM" # Use standard termination signal
    }
  }
}
