# -------------------------------------------------------------------------------
# Woodpecker Agent — CI/CD Pipeline Executor
#
# Project: Munchbox / Author: Alex Freidah
#
# Woodpecker agent executes pipeline steps in isolated containers. Connects to
# the Woodpecker server via gRPC to receive build jobs. Requires Docker socket
# access for container orchestration during builds.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "woodpecker-agent"
type  = "service"
image = "woodpeckerci/woodpecker-agent:v3.12.0"
size  = "large"

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/var/run/docker.sock:/var/run/docker.sock"
]

# --- Vault integration ---
vault = true

# --- Templates (inject secrets from Vault) ---
templates = [
  { src = "woodpecker-agent.env.tpl", dest = "/secrets/woodpecker.env", env = true, vault = true }
]

# --- Environment variables ---
env = {
  # Using Consul DNS - server uses host networking so gRPC port 9000 is accessible on the resolved IP
  WOODPECKER_SERVER             = "woodpecker-server.service.consul:9000"
  WOODPECKER_BACKEND            = "docker"
  WOODPECKER_LOG_LEVEL          = "info"
  WOODPECKER_HEALTHCHECK        = "false"
  DOCKER_HOST                   = "unix:///var/run/docker.sock"
  DOCKER_API_VERSION            = "1.44"
  TZ                            = "America/Los_Angeles"
}

# --- Health check ---
health_type = "none"

# --- Service tags ---
tags = [
  "woodpecker",
  "agent",
  "ci",
  "infrastructure"
]

# --- Termination ---
kill_timeout = "60s"
