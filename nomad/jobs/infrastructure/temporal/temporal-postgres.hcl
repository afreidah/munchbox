# -------------------------------------------------------------------------------
# Temporal — PostgreSQL Database
#
# Project: Munchbox
# Author: Alex Freidah
#
# PostgreSQL 15 backend for Temporal workflow engine. Persistent storage
# on stabler node with host networking for simplified connectivity.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "temporal-postgres"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
priority        = 50

job_description = "Temporal PostgreSQL database backend — persistent storage"

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "stabler"
  }
]

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier-2"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "medium"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "db"
    static = 5432
    port   = 5432
  }
]

# -----------------------------------------------------------------------
# Storage & Volumes
# -----------------------------------------------------------------------

volume = {
  name       = "temporal-postgres-data"
  type       = "host"
  source     = "temporal-postgres-data"
  read_only  = false
  mount_path = "/var/lib/postgresql/data"
}

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "postgres"
  driver = "docker"

  config = {
    image              = "postgres:15-alpine"
    image_pull_timeout = "10m"
    network_mode       = "host"
    ports              = ["db"]
  }

  env = {
    TZ                = "UTC"
    POSTGRES_USER     = "temporal"
    POSTGRES_PASSWORD = "temporal"
    POSTGRES_DB       = "temporal"
  }

  service = {
    name     = "temporal-postgres"
    port     = "db"
    provider = "consul"
    tags = [
      "temporal",
      "postgres",
      "database"
    ]
  }

  resources = {
    cpu    = 500
    memory = 512
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  medium = {
    cpu             = 500
    memory          = 512
    ephemeral_disk  = 1000
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  standard = {
    max_parallel      = 1
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  tier-2 = {
    tier = "tier-2"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    max_reschedules = 3
    delay           = "5s"
    delay_function  = "exponential"
    unlimited       = false
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  host = {
    mode = "host"
  }
}
