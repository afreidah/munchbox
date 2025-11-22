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
    TEMPORAL_ADDRESS  = "temporal-server.service.consul:7233"
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

# --- Vault integration ---
vault_role = "nomad-workloads"

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
