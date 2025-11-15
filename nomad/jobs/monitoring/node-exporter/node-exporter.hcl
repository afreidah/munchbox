# -------------------------------------------------------------------------------
# Prometheus Node Exporter — System Metrics Collection Service
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs node_exporter on every cluster node via system job, exposing CPU,
# memory, disk, network, and system metrics on port 9100. Uses host networking
# for direct port binding and Consul service discovery.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "node-exporter"
job_type        = "system"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Prometheus Node Exporter - System metrics collection"

# --- Deployment and metadata ---
deployment_profile = "rolling"
meta_profile       = "standard"
category           = "monitoring"

# --- Resource allocation ---
resource_tier = "tiny"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 9100
  }
]

# --- Task definition ---
task = {
  name   = "prometheus_node_exporter"
  driver = "docker"

  config = {
    image        = "quay.io/prometheus/node-exporter:v1.8.2"
    network_mode = "host"
    pid_mode     = "host"
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
    volumes = [
      "/:/host:ro,rslave"
    ]
  }

  env = {
    TZ                               = "America/Los_Angeles"
    NODE_EXPORTER_WEB_TELEMETRY_PATH = "/metrics"
  }

  services = [
    {
      name     = "prometheus-node-exporter"
      port     = "http"
      provider = "consul"
      tags     = ["monitoring", "node-exporter", "metrics", "system"]
      checks = [
        {
          name     = "node-exporter-alive"
          type     = "http"
          path     = "/metrics"
          interval = "15s"
          timeout  = "3s"
          check_restart = {
            limit = 3
            grace = "10s"
          }
        },
        {
          name     = "node-exporter-metrics"
          type     = "http"
          path     = "/metrics"
          interval = "60s"
          timeout  = "5s"
        }
      ]
    }
  ]

  resources = {
    cpu    = 150
    memory = 64
  }
}

# --- Turn off standard service since we're using services array ---
standard_service_enabled = false

# --- Restart policy ---
restart_attempts = 10
restart_interval = "5m"
restart_delay    = "5s"
restart_mode     = "delay"

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Resource tier definitions ---
resource_tiers = {
  tiny = {
    cpu            = 150
    memory         = 64
    ephemeral_disk = 300
  }
}

# --- Network presets ---
network_presets = {
  host = {
    mode = "host"
  }
}

# --- Deployment profiles ---
deployment_profiles = {
  rolling = {
    max_parallel      = 2
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "2m"
    progress_deadline = "5m"
    auto_revert       = true
  }
}

# --- Meta profiles ---
meta_profiles = {
  standard = {
    version = "1.8.2"
    updated = "2025-10-11"
  }
}
