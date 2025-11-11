# -------------------------------------------------------------------------------
# Temporal Backup Worker — Long-Running Workflow Execution Service
#
# Project: Munchbox
# Author: Alex Freidah
#
# Executes Temporal backup workflows triggered by the backup-trigger job via
# the backup-task-queue. Performs snapshot operations for Nomad, Consul, and
# OpenBao, storing backups on /mnt/gdrive with 7-day retention. Requires Vault
# credentials for cluster access and dedicated node placement on mccoy.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "temporal-backup-worker"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal backup worker for Nomad, Consul, and OpenBao snapshots"

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "automation"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "small"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 10
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Vault Integration
# -----------------------------------------------------------------------

vault = {
  enabled = true
  role    = "nomad-workloads"
  aud     = ["vault.io"]
}

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "worker"
  driver = "raw_exec"

  identity = {
    env  = true
    file = true
    aud  = ["vault.io"]
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

  templates = [
    {
      destination = "secrets/tokens.env"
      perms       = "0600"
      env         = true
      change_mode = "restart"
      data        = <<-EOH
{{ with secret "kv/data/backup-worker" -}}
NOMAD_TOKEN={{ .Data.data.nomad_token }}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
{{- end }}
EOH
    }
  ]

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

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  tiny = {
    cpu            = 150
    memory         = 128
    ephemeral_disk = 200
  }
  small = {
    cpu            = 200
    memory         = 256
    ephemeral_disk = 500
  }
  medium = {
    cpu            = 500
    memory         = 1024
    ephemeral_disk = 1000
  }
  large = {
    cpu            = 2000
    memory         = 4096
    ephemeral_disk = 2000
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  bridge = {
    mode = "bridge"
  }
  host = {
    mode = "host"
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

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

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  tier2 = {
    tier = "important"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    delay           = "5s"
    delay_function  = "exponential"
    max_reschedules = 3
    unlimited       = false
  }
}
