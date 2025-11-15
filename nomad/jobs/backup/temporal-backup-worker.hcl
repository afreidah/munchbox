# -------------------------------------------------------------------------------
# Temporal Backup Worker — Long-Running Workflow Execution Service
#
# Project: Munchbox / Author: Alex Freidah
#
# Executes Temporal backup workflows triggered by the backup-trigger job via
# the backup-task-queue. Performs snapshot operations for Nomad, Consul, and
# OpenBao, storing backups on /mnt/gdrive with 7-day retention.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "temporal-backup-worker"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal backup worker for Nomad, Consul, and OpenBao snapshots"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "automation"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "host"

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# --- Restart policy ---
restart_attempts = 10
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/backup/files"
}

external_templates = [
  {
    destination = "secrets/tokens.env"
    source_file = "tokens.env.tpl"
    env         = true
    change_mode = "restart"
  }
]

# --- Task definition ---
task = {
  name   = "worker"
  driver = "raw_exec"

  identity = {
    env  = true
    file = true
    aud  = ["vault.io"]
  }

  vault = {
    role = "nomad-workloads"
  }

  config = {
    command = "/usr/local/bin/temporal-backup-worker"
  }

  env = {
    TEMPORAL_ADDRESS  = "192.168.68.61:7233"
    NOMAD_ADDR        = "https://$${attr.unique.network.ip-address}:4646"
    NOMAD_SKIP_VERIFY = "true"
    CONSUL_HTTP_ADDR  = "$${attr.unique.network.ip-address}:8500"
    BAO_ADDR          = "https://mccoy:8200"
    BAO_SKIP_VERIFY   = "true"
  }

  services = [
    {
      name     = "temporal-backup-worker"
      provider = "consul"
      tags = [
        "temporal",
        "backup",
        "worker"
      ]
    }
  ]

  resources = {
    cpu        = 200
    memory     = 256
    memory_max = 512
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Deployment profiles ---
deployment_profiles = {
  standard = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = false
    canary            = 0
  }
}

# --- Meta profiles ---
meta_profiles = {
  tier2 = {
    tier = "important"
  }
}

# --- Reschedule presets ---
reschedule_presets = {
  standard = {
    delay           = "5s"
    delay_function  = "exponential"
    max_reschedules = 3
    unlimited       = false
  }
}
