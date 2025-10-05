# -------------------------------------------------------------------------------
#  GitHub Actions Runner — Nomad Service Job
#
#  * Self-hosted GitHub Actions runners for CI/CD workloads.
#  * Dynamically registers/deregisters with GitHub on allocation start/stop.
#  * Uses ephemeral runners (auto-removed after each job completes).
#  * Supports Docker-in-Docker for container builds via privileged mode.
#  * Scales horizontally across cluster nodes for concurrent job execution.
#  * Pulls GitHub token from Vault (OpenBao) for secure registration.
#  * Tags runners with labels for workflow job targeting (e.g., "nomad", "linux").
#
#  CONFIGURATION NOTES:
#    - Set repo_url or org_url in Vault KV secret for target repo/org.
#    - Ephemeral mode means runners auto-cleanup after each job.
#    - Privileged mode is required for Docker builds; review security implications.
#    - Consider Docker socket binding vs. DinD based on your security posture.
#    - Scale count based on expected concurrent workflow runs.
#
#  VAULT SECRET PATH:
#    - kv/data/github/runner
#      Required fields:
#        * token: GitHub PAT with repo + admin:org scopes
#        * repo_url: Target repository URL (e.g., https://github.com/user/repo)
#      Optional fields:
#        * org_url: Organization URL (alternative to repo_url for org-wide runners)
#        * runner_group: Runner group name (for organization runners)
#
#  CHANGELOG:
#    - 2025-10-04: Initial job creation
#    - Use myoung34/github-runner for ephemeral runner support
#    - Migrate from Consul KV to Vault (OpenBao) for secret management
#    - Spread runners across distinct hosts for better resource distribution
#    - Added runner work directory cleanup on stop
# -------------------------------------------------------------------------------

job "github-runner" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # Update strategy - rolling updates to minimize disruption
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  # Spread runners across different nodes for better resource usage
  group "runner" {
    count = 2 # Scale based on concurrent workflow needs

    # Distribute runners across distinct hosts
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    # Avoid running on the same node as resource-heavy services
    constraint {
      attribute = "${node.unique.name}"
      operator  = "!="
      value     = "mccoy" # Node running GitLab/heavy workloads
    }

    # ---------------------------------------------------------------------------
    #  Ephemeral storage for runner work directory
    # ---------------------------------------------------------------------------
    ephemeral_disk {
      size    = 5000 # 5GB for build artifacts and caches
      migrate = false
      sticky  = false
    }

    # ---------------------------------------------------------------------------
    #  Networking - host mode for Docker socket access
    # ---------------------------------------------------------------------------
    network {
      mode = "host"
    }

    # Restart policy - runners should restart on failure
    restart {
      attempts = 10
      interval = "10m"
      delay    = "30s"
      mode     = "delay"
    }

    # ---------------------------------------------------------------------------
    #  GitHub Actions Runner Task
    # ---------------------------------------------------------------------------
    task "runner" {
      driver = "docker"

      # Workload identity for Vault authentication
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # Vault integration using nomad-workloads role
      vault {
        role = "nomad-workloads"
      }

      config {
        # Official community image with ephemeral runner support
        image              = "myoung34/github-runner:latest"
        image_pull_timeout = "10m"
        network_mode       = "host"

        # Privileged mode required for Docker-in-Docker builds
        # SECURITY: Review if all workflows need this capability
        privileged = true

        # Mount Docker socket for container builds
        # Alternative: Use Docker-in-Docker if security requires isolation
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "github-runner-${NOMAD_ALLOC_INDEX}"
          }
        }
      }

      # ---------------------------------------------------------------------------
      #  Service registration - optional monitoring endpoint
      # ---------------------------------------------------------------------------
      service {
        name     = "github-runner"
        provider = "consul"

        tags = [
          "ci",
          "github-actions",
          "runner",
          "nomad-${NOMAD_ALLOC_INDEX}"
        ]
      }

      # ---------------------------------------------------------------------------
      #  GitHub configuration from Vault (OpenBao)
      #
      #  Pulls secrets from: kv/data/github/runner
      #  Required secret fields:
      #    - token: GitHub Personal Access Token (PAT) with repo + admin:org scopes
      #    - repo_url: Target repository URL (or org_url for organization-wide)
      # ---------------------------------------------------------------------------
      template {
  data = <<EOH
{{ with secret "kv/data/github/runner" }}
# GitHub authentication token (PAT with repo + admin:org scopes)
ACCESS_TOKEN="{{ .Data.data.token }}"

# Organization URL to register runner with
{{ if .Data.data.org_url }}ORG_URL="{{ .Data.data.org_url }}"{{ end }}

# Repository URL (alternative to ORG_URL for repo-specific runners)
{{ if .Data.data.repo_url }}REPO_URL="{{ .Data.data.repo_url }}"{{ end }}

# Optional: Runner group for organization runners
{{ if .Data.data.runner_group }}RUNNER_GROUP="{{ .Data.data.runner_group }}"{{ end }}
{{ end }}

# Runner configuration
RUNNER_NAME={{ env "NOMAD_ALLOC_NAME" }}-{{ env "NOMAD_ALLOC_ID" }}
RUNNER_WORKDIR=/tmp/runner-work
EPHEMERAL=false

# Labels for workflow job targeting
LABELS=nomad,self-hosted,linux,x64,docker

# Disable automatic updates (controlled via Docker image)
DISABLE_AUTO_UPDATE=true
EOH
        destination = "secrets/github.env"
        env         = true
      }

      # ---------------------------------------------------------------------------
      #  Environment variables
      # ---------------------------------------------------------------------------
      env {
        # Timezone for log timestamps
        TZ = "America/Los_Angeles"

        # Docker-in-Docker configuration (if not using socket binding)
        # DOCKER_ENABLED = "true"
        # DOCKER_TLS_VERIFY = "false"

        # Runner behavior
        START_DOCKER_SERVICE = "false" # Using host Docker socket
      }

      # ---------------------------------------------------------------------------
      #  Resource allocation
      #
      #  Memory: GitHub Actions jobs can be memory-intensive during builds.
      #          Allocate based on your typical workflow requirements.
      #  CPU: Reserve enough shares for parallel build steps.
      # ---------------------------------------------------------------------------
      resources {
        cpu    = 2000 # ~2 CPU cores worth of shares
        memory = 2048 # 2GB RAM - adjust based on build requirements
      }

      # Lifecycle management
      kill_timeout   = "120s" # Allow time for job cleanup
      kill_signal    = "SIGTERM"
      shutdown_delay = "10s"
    }
  }
}
