# -------------------------------------------------------------------------------
# Prometheus Node Exporter — System Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# System job running on every node to expose hardware and OS metrics. Uses host
# networking and full filesystem access for accurate system monitoring. Scraped
# by Prometheus via Consul service discovery.
# -------------------------------------------------------------------------------

job_name        = "node-exporter"
job_type        = "system"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
node_pool       = "all"
priority        = 50
job_description = "Prometheus Node Exporter - hardware and OS metrics collection"

meta_profile = "tier2"
category     = "monitoring"

resource_tier  = "tiny"
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 9100
  }
]

task = {
  name   = "node-exporter"
  driver = "docker"

  config = {
    image        = "quay.io/prometheus/node-exporter:v1.8.2"
    network_mode = "host"
    pid_mode     = "host"
    ports        = ["http"]
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
    TZ = "America/Los_Angeles"
  }

  resources = {
    cpu    = 150
    memory = 64
  }
}

consul_connect_enabled = false

standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 9100
standard_http_check_enabled  = true
standard_http_check_path     = "/metrics"

additional_tags = [
  "monitoring",
  "node-exporter",
  "metrics",
  "system"
]

kill_timeout = "30s"
kill_signal  = "SIGTERM"
