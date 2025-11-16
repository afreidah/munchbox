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
job_description = "Prometheus Node Exporter - System metrics collection"
node_pool       = "all"

# --- Metadata ---
category = "monitoring"

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

# --- Turn off standard service since we're using custom services array ---
standard_service_enabled = false
