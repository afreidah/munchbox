# -------------------------------------------------------------------------------
# Node Exporter — System Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# System job running on every node to expose hardware and OS metrics for
# Prometheus scraping. Uses host networking and PID namespace for accurate
# system monitoring including CPU, memory, disk, and network statistics.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "node-exporter"
type         = "system"
image        = "quay.io/prometheus/node-exporter:v1.10.2"
port         = 9100
static_port  = 9100
host_network = true
size         = "tiny"

# --- Traefik routing ---
traefik = true

# --- Health check ---
health_path = "/metrics"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Container arguments ---
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

# --- Host volume mounts ---
volumes = [
  "/:/host:ro,rslave"
]

# --- Docker configuration ---
docker_extra = {
  pid_mode = "host"
}

# --- Service tags ---
tags = ["monitoring", "node-exporter", "metrics", "system"]
