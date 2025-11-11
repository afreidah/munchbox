# -------------------------------------------------------------------------------
# Temporal Backup Trigger — Daily Scheduled Backup Orchestration
#
# Project: Munchbox
# Author: Alex Freidah
#
# Initiates daily backups of HashiCorp infrastructure via Temporal workflows.
# Runs daily at 2:00 AM Pacific, triggering snapshots of Nomad, Consul, and
# OpenBao clusters executed by the temporal-backup-worker service on mccoy.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "temporal-backup-trigger"
job_type        = "batch"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Daily backup trigger for Temporal workflows"

# -----------------------------------------------------------------------
# Periodic Schedule
# -----------------------------------------------------------------------

periodic = {
  enabled          = true
  cron             = "0 2 * * *"
  prohibit_overlap = true
  time_zone        = "America/Los_Angeles"
}

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "automation"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "tiny"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# Don't set reschedule_preset for batch jobs - causes validation errors

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "trigger"
  driver = "raw_exec"

  config = {
    command = "/usr/local/bin/temporal-backup-trigger"
  }

  env = {
    TEMPORAL_ADDRESS = "192.168.68.61:7233"
  }

  resources = {
    cpu    = 100
    memory = 128
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  tiny = {
    cpu            = 100
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
# Reschedule Presets (Not used for batch jobs)
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    delay           = "30s"
    delay_function  = "constant"
    max_reschedules = 3
    unlimited       = false
  }
}
