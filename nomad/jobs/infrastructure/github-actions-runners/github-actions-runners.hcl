# -------------------------------------------------------------------------------
# GitHub Actions Runner — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# Scalable, isolated CI runners using github-runner with Debian Trixie.
# Backed by Vault workload identity for secure PAT and repository access.
# Docker socket passthrough for containerized build execution.
# Dynamic service discovery via Consul.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "github-runner"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
priority        = 50

job_description = "GitHub Actions CI runner — scalable, Vault-backed, Docker-enabled"

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "node.unique.name"
    operator  = "!="
    value     = "mccoy"
  }
]

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "canary"
meta_profile       = "tier-1"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "large"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 10
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "delay"

reschedule_preset = "aggressive"

# -----------------------------------------------------------------------
# Task Group Configuration
# -----------------------------------------------------------------------

group_name = "runner"
count      = 2

# -----------------------------------------------------------------------
# Vault Integration
# -----------------------------------------------------------------------

vault = {
  enabled       = true
  role          = "nomad-workloads"
  change_mode   = "restart"
  change_signal = "SIGTERM"
  env           = true
  aud           = ["vault.io"]
}

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "runner"
  driver = "docker"

  identity = {
    env  = true
    file = true
    aud  = ["vault.io"]
  }

  config = {
    image              = "docker-mirror.service.consul:5000/github-runner-waypoint:latest"
    image_pull_timeout = "10m"
    network_mode       = "host"
    privileged         = true
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
    ]
  }

  templates = [
    {
      destination = "secrets/github.env"
      env         = true
      change_mode = "restart"
      data        = <<-EOF
{{- with secret "kv/data/github/runner" }}
ACCESS_TOKEN="{{ .Data.data.token }}"
{{- if .Data.data.org_url }}
ORG_URL="{{ .Data.data.org_url }}"
{{- end }}
{{- if .Data.data.repo_url }}
REPO_URL="{{ .Data.data.repo_url }}"
{{- end }}
{{- if .Data.data.runner_group }}
RUNNER_GROUP="{{ .Data.data.runner_group }}"
{{- end }}
{{- end }}
RUNNER_NAME={{ env "NOMAD_ALLOC_NAME" }}-{{ env "NOMAD_ALLOC_ID" }}
RUNNER_WORKDIR=/tmp/runner-work
EPHEMERAL=true
LABELS=nomad,self-hosted,linux,docker
RUNNER_VERSION=latest
DISABLE_AUTO_UPDATE=true
EOF
    }
  ]

  env = {
    TZ                   = "America/Los_Angeles"
    START_DOCKER_SERVICE = "false"
    RUN_AS_ROOT          = "false"
  }

  service = {
    name     = "github-runner"
    provider = "consul"
    tags = [
      "ci",
      "github-actions",
      "runner"
    ]
  }

  resources = {
    cpu    = 2000
    memory = 2048
  }

  kill_timeout   = "120s"
  kill_signal    = "SIGTERM"
  shutdown_delay = "10s"

  restart = {
    attempts = 10
    interval = "10m"
    delay    = "30s"
    mode     = "delay"
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  large = {
    cpu             = 2000
    memory          = 2048
    ephemeral_disk  = 5000
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  canary = {
    max_parallel      = 1
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  tier-1 = {
    tier = "critical"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  aggressive = {
    max_reschedules = 5
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
