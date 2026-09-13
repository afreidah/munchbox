# -------------------------------------------------------------------------------
# Forgejo Build Runner - on-demand ephemeral runner for image builds
#
# Project: Munchbox / Author: Alex Freidah
#
# Dispatched per queued `build` job by the ci-runner-scaler, the same way
# forgejo-ci-runner is, and one-shot for the same reason: it registers, runs a
# single job, and exits.
#
# It exists separately so image builds do not run on the runner that carries
# cluster credentials. act_runner mounts the Docker socket into the workflow
# container by itself whenever docker_host names one, so the socket is not what
# distinguishes the two -- mounting it again here is a duplicate mount and the
# container fails to create.
#
# The split reduces blast radius rather than enforcing a boundary: a job picks
# its own runner with runs-on, and Forgejo action secrets are per repository.
#
# Placement is the proxmox clients rather than the oracle nodes: more cores and
# disk, and the amd64 half of a multi-arch build runs native there. Nothing here
# talks to Nomad or Vault, so unlike the deploy runner it mounts no CA.
#
#   nomad job run forgejo-build-runner.nomad.hcl
#   nomad job dispatch -meta repo_url=... -meta runner_token=... \
#     -meta labels=build forgejo-build-runner
# -------------------------------------------------------------------------------

job "forgejo-build-runner" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "default"

  parameterized {
    meta_required = ["repo_url", "runner_token"]
    meta_optional = ["labels"]
  }

  meta {
    labels = "build"
  }

  group "runner" {
    count = 1

    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "amd64"
    }

    constraint {
      attribute = "${meta.role}"
      operator  = "!="
      value     = "ingress" # a build must not be able to starve the VIP
    }

    network {
      mode = "host"
    }

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
      user   = "root" # the image's default user cannot reach the socket

      config {
        image        = "code.forgejo.org/forgejo/runner:12.13.0"
        network_mode = "host"
        privileged   = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "local/config.yaml:/config.yaml:ro",
        ]

        entrypoint = ["/bin/sh"]
        args = [
          "-c",
          "/bin/forgejo-runner register --no-interactive --config /config.yaml --instance \"$FORGEJO_INSTANCE\" --token \"$RUNNER_TOKEN\" --name \"$RUNNER_NAME\" --labels \"$RUNNER_LABELS\" && exec /bin/forgejo-runner one-job --config /config.yaml --wait",
        ]
      }

      # Runner configuration. capacity 1 pairs with one-job: one workflow job
      # per allocation. The cache server is off because its directory dies with
      # the allocation. The 3h timeout is longer than the deploy runner's
      # because the foreign half of a multi-arch build is emulated, which is
      # slow for an image carrying a language toolchain.
      #
      # --user root because ops-build-image runs as uid 10001 and the host's
      # docker socket is root-owned, so buildx cannot reach it otherwise.
      # force_pull because the image is tagged :latest: a node that already
      # cached it would otherwise keep running a stale toolchain forever.
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
          force_pull: true
          options: "--dns=192.168.68.64 --dns=192.168.68.62 --user root"
          valid_volumes:
            - /var/run/docker.sock
          docker_host: unix:///var/run/docker.sock
        EOF
        destination = "local/config.yaml"
      }

      # Registered with `build` alone, spelled out here rather than taken from
      # the dispatch's own meta.labels: a runs-on label arrives bare and carries
      # no image, so the runner would otherwise fall back to its built-in
      # default.
      #
      # Only `build`. one-job takes the oldest queued job matching any label the
      # runner registered, so a second label lets unrelated work hijack a runner
      # dispatched for an image build -- the mirrored .github workflows queue
      # plenty of `ubuntu-latest` jobs, and those are forgejo-ci-runner's.
      env {
        FORGEJO_INSTANCE = "http://forgejo.service.consul:30028"

        RUNNER_TOKEN = "${NOMAD_META_runner_token}"
        RUNNER_NAME  = "forgejo-build-${NOMAD_ALLOC_ID}"
        REPO_URL     = "${NOMAD_META_repo_url}"

        RUNNER_LABELS = "build:docker://registry.munchbox.cc/ops-build-image:latest"
      }

      resources {
        cpu    = 4000
        memory = 4096
      }

      kill_timeout = "60s"
    }
  }
}
