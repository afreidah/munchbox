# -------------------------------------------------------------------------------
# GitHub Actions Runner — Self-Hosted CI/CD Agents
#
# Project: Munchbox / Author: Alex Freidah
#
# Scalable, isolated CI runners using github-runner with Debian Trixie.
# Backed by Vault workload identity for secure PAT and repository access.
# Docker socket passthrough for containerized build execution.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "github-runner"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "GitHub Actions CI runner — scalable, Vault-backed, Docker-enabled"
count           = 2

# --- Deployment and metadata ---
deployment_profile = "canary"
meta_profile       = "tier1"
category           = "ci-cd"

# --- Resource allocation ---
resource_tier = "large"

# --- Network configuration ---
network_preset = "host"

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "!="
    value     = "mccoy"
  }
]

# --- Restart policy ---
restart_attempts = 10
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "aggressive"

# --- Vault integration ---
vault_role = "nomad-workloads"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/infrastructure/github-actions-runners/files"
}

external_templates = [
  {
    destination = "secrets/github.env"
    source_file = "github.env.tpl"
    env         = true
    perms       = "0600"
    change_mode = "restart"
  }
]

# --- Task definition ---
task = {
  name   = "runner"
  driver = "docker"

  config = {
    image              = "registry.munchbox.cc/github-runner-waypoint:latest"
    image_pull_timeout = "10m"
    privileged         = true
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
    ]
  }

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
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "120s"
kill_signal  = "SIGTERM"
