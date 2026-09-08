# -------------------------------------------------------------------------------
# Forgejo CI Runner — on-demand ephemeral Forgejo Actions runner (parameterized)
#
# Project: Munchbox / Author: Alex Freidah
#
# A parameterized batch job: each dispatch registers one runner, runs a single
# job, and exits. The runnerscaler Temporal workflow polls the Forgejo Actions
# API for waiting jobs, mints a registration token per dispatch, and passes it as
# meta, so the credential a runner receives is spent once and nothing long-lived
# reaches it.
#
#   nomad job run forgejo-ci-runner.nomad.hcl   # register the parameterized job
#   nomad job dispatch \                        # spawn one runner
#     -meta repo_url=http://forgejo.service.consul:30028/alex/munchbox \
#     -meta runner_token=<registration-token> \
#     -meta labels=ubuntu-latest \
#     forgejo-ci-runner
#
# This replaces the long-lived forgejo-runner daemon, which held a privileged
# container with the Docker socket mounted around the clock to serve work that
# arrives in bursts; here that exposure lasts only as long as a job runs.
#
# No vault{} block: unlike the GitHub ci-runner, workflows here read their
# cluster credentials from Forgejo repository action secrets, synced from Vault
# by terragrunt (_env_helpers/forgejo-secrets.hcl). The runner itself needs no
# secret beyond the registration token in its dispatch meta.
# -------------------------------------------------------------------------------

job "forgejo-ci-runner" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "oracle"

  # --- Dispatched per queued job; meta carries the target repo + minted token ---
  parameterized {
    meta_required = ["repo_url", "runner_token"]
    meta_optional = ["labels"]
  }

  # --- Default when a dispatch omits it. Only the runner name reads this; see
  #     the registration note below for why it does not drive --labels ---
  meta {
    labels = "ubuntu-latest"
  }

  group "runner" {
    count = 1

    # --- The oracle micro nodes have 1 GB of RAM; a workflow container does not
    #     fit beside the runner there. Same placement the daemon ran under ---
    constraint {
      attribute = "${meta.tier}"
      operator  = "!="
      value     = "micro"
    }

    # --- Host network so a workflow container reaches cluster services at their
    #     Consul addresses, matching how the daemon's jobs resolved them ---
    network {
      mode = "host"
    }

    # --- One-shot: the runner takes a single job then exits. A finished or
    #     failed runner is never restarted or rescheduled; if the job is still
    #     queued the scaler dispatches a fresh one on its next tick ---
    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "runner" {
      driver = "docker"

      # --- The image defaults to a non-root user that cannot reach the host
      #     Docker socket ---
      user = "root"

      config {
        image        = "code.forgejo.org/forgejo/runner:12.13.0"
        network_mode = "host"
        privileged   = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "local/config.yaml:/config.yaml:ro",
        ]

        # Register against the instance, then take exactly one job and exit.
        # `one-job` is the runner's own ephemeral mode; --wait blocks until a
        # matching job is assigned rather than exiting on a momentarily empty
        # queue, which would race the dispatch that created this runner.
        entrypoint = ["/bin/sh"]
        args = [
          "-c",
          "/bin/forgejo-runner register --no-interactive --config /config.yaml --instance \"$FORGEJO_INSTANCE\" --token \"$RUNNER_TOKEN\" --name \"$RUNNER_NAME\" --labels \"$RUNNER_LABELS\" && exec /bin/forgejo-runner one-job --config /config.yaml --wait",
        ]
      }

      # --- Runner configuration. capacity 1 pairs with one-job: one workflow
      #     job per allocation. The cache server is off because its directory
      #     dies with the allocation, so it would only ever miss ---
      template {
        data        = <<-EOF
        log:
          level: info

        runner:
          file: /data/.runner
          capacity: 1
          timeout: 3h
          insecure: false
          fetch_timeout: 5s
          fetch_interval: 2s

        cache:
          enabled: false

        container:
          network: host
          privileged: true
          options: "--dns=192.168.68.64 --dns=192.168.68.62"
          valid_volumes:
            - /var/run/docker.sock
          docker_host: unix:///var/run/docker.sock
        EOF
        destination = "local/config.yaml"
      }

      env {
        # Internal Forgejo address; the public host sits behind oauth2-proxy,
        # which a runner cannot authenticate through.
        FORGEJO_INSTANCE = "http://forgejo.service.consul:30028"

        RUNNER_TOKEN = "${NOMAD_META_runner_token}"
        RUNNER_NAME  = "forgejo-ci-${NOMAD_ALLOC_ID}"
        REPO_URL     = "${NOMAD_META_repo_url}"

        # --- Registered with the full label set rather than the dispatch's own
        #     meta.labels. A runs-on label arrives bare ("ubuntu-latest"), and a
        #     bare label carries no image, so the runner would fall back to its
        #     built-in default image instead of the one that label means here.
        #     The scaler still buckets dispatches by meta.labels, so a superset
        #     runner does not overshoot: one job is taken, then the process
        #     exits. ---
        RUNNER_LABELS = "self-hosted:host,docker:docker://catthehacker/ubuntu:act-latest,ubuntu-latest:docker://catthehacker/ubuntu:act-latest,ubuntu-22.04:docker://catthehacker/ubuntu:act-22.04,ops:docker://registry.munchbox.cc/ops-build-image:latest"
      }

      # --- Ephemeral one-shot, so a flat reservation carries no idle cost ---
      resources {
        cpu    = 2000
        memory = 2048
      }

      kill_timeout = "60s"
    }
  }
}
