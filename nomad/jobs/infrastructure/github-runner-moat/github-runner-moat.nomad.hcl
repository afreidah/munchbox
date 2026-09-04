# -------------------------------------------------------------------------------
# GitHub Actions Runner — moat (private repo, on-demand)
#
# Project: Munchbox / Author: Alex Freidah
#
# Parameterized batch job: each dispatch spawns one EPHEMERAL self-hosted runner
# (takes a single job, then deregisters and exits) for the private `moat` repo,
# so its CI runs without burning paid hosted-runner minutes and without an
# always-on pool. Dispatched by the Temporal ci-runner-scaler when moat has a
# queued self-hosted job (vault-mode: the scaler polls with the moat PAT and
# dispatches this job, minting nothing).
#
# moat is not our repo, so the GitHub App can't be installed on it to mint runner
# registration tokens. Instead the runner self-registers from a fine-grained PAT
# (Administration: Read+Write on moat) read from Vault via workload identity --
# the same secret the old always-on pool used. The scaler passes repo_url/labels
# (and, for app-mode repos, runner_token) as meta purely so it can identify the
# dispatched runner when it reconciles; this job reads its own credential from
# Vault and ignores them. Docker socket is mounted so workflow steps can build
# images and run containers. Runs on the amd64 Proxmox VMs (moat's Packer/Kitchen/
# Cinc flows expect native amd64).
#
#   nomad job run github-runner-moat.nomad.hcl   # register the parameterized job
#   nomad job dispatch \                          # spawn one runner (scaler does this)
#     -meta repo_url=https://github.com/ev-the-dev/moat \
#     -meta labels=self-hosted,moat \
#     github-runner-moat
# -------------------------------------------------------------------------------

job "github-runner-moat" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "default"

  # --- Dispatched per queued moat job; all meta is bookkeeping for the scaler,
  #     so it is optional -- the runner's credential comes from Vault below. ---
  parameterized {
    # runner_secret is permitted but unused: the scaler sends it on every
    # vault-mode dispatch; this job reads its own secret/data/github/moat-runner.
    meta_optional = ["repo_url", "labels", "runner_token", "runner_secret"]
  }

  group "runner" {
    count = 1

    # these guys require a lot of resources so limit them to the heaviest nodes
    constraint {
      attribute = "nomad-client-04,nomad-client-05"
      operator  = "set_contains"
      value     = "${attr.unique.hostname}"
    }

    network {
      mode = "host"
    }

    # --- One-shot: an ephemeral runner runs a single job then exits; never
    #     restart or reschedule a finished/failed runner ---
    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    # -------------------------------------------------------------------------
    # Task: runner
    # -------------------------------------------------------------------------

    task "runner" {
      driver = "docker"

      vault {
        role        = "github-runner-moat"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image          = "registry.munchbox.cc/moat-runner-standard:1.0.3"
        privileged     = true
        cpu_hard_limit = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }

      env {
        TZ                   = "America/Los_Angeles"
        START_DOCKER_SERVICE = "false"
        RUN_AS_ROOT          = "false"
      }

      # --- Registration credentials from Vault (the runner self-registers from
      #     the PAT; the scaler mints nothing for this repo). ---
      template {
        data        = <<-EOF
{{- with secret "secret/data/github/moat-runner" }}
ACCESS_TOKEN="{{ .Data.data.token }}"
REPO_URL="{{ .Data.data.repo_url }}"
{{- if .Data.data.runner_group }}
RUNNER_GROUP="{{ .Data.data.runner_group }}"
{{- end }}
{{- end }}
RUNNER_NAME=moat-runner-{{ env "NOMAD_ALLOC_ID" }}
RUNNER_WORKDIR=/tmp/runner-work
RUNNER_SCOPE=repo
EPHEMERAL=true
LABELS=nomad,self-hosted,linux,x64,docker,moat
RUNNER_VERSION=latest
DISABLE_AUTO_UPDATE=true
EOF
        destination = "secrets/github.env"
        env         = true
        perms       = "0600"
        change_mode = "noop"
      }

      resources {
        cpu    = 6000
        memory = 2176
      }

      kill_timeout = "120s"
      kill_signal  = "SIGTERM"
    }
  }
}
