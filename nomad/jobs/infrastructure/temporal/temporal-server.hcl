# -------------------------------------------------------------------------------
# Temporal — Server with gRPC API
#
# Project: Munchbox
# Author: Alex Freidah
#
# Temporal server with auto-setup connecting to PostgreSQL backend.
# gRPC API on port 7233 for workflow submissions and queries.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "temporal-server"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
priority        = 50

job_description = "Temporal server — workflow orchestration engine with gRPC API"

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

resource_tier = "large"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "frontend"
    static = 7233
    port   = 7233
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
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "temporal"
  driver = "docker"

  config = {
    image              = "temporalio/auto-setup:1.25.0"
    image_pull_timeout = "10m"
    network_mode       = "host"
    ports              = ["frontend"]
  }

  env = {
    TZ             = "UTC"
    DB             = "postgres12_pgx"
    DB_PORT        = "5432"
    POSTGRES_USER  = "temporal"
    POSTGRES_PWD   = "temporal"
    POSTGRES_SEEDS = "localhost"
  }

  service = {
    name     = "temporal-frontend"
    port     = "frontend"
    provider = "consul"
    tags = [
      "temporal",
      "frontend",
      "grpc"
    ]
  }

  resources = {
    cpu    = 1000
    memory = 1024
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  large = {
    cpu             = 1000
    memory          = 1024
    ephemeral_disk  = 2000
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
