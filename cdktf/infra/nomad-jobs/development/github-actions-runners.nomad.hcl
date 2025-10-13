# -------------------------------------------------------------------------------
#  GitHub Actions Runner — Nomad Service Job (Debian Trixie + Node20 preseed)
#
#  - Uses myoung34/github-runner:debian-trixie
#  - EPHEMERAL runners (auto-cleanup per job)
#  - Host Docker socket for builds (privileged)
#  - Vault (OpenBao) for PAT + repo/org settings
#  - Prestart task seeds Node 20 into /actions-runner/externals/node20
#    to fix: "/__e/node20/bin/node: no such file or directory"
# -------------------------------------------------------------------------------

job "github-runner" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  group "runner" {
    count = 2

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    constraint {
      attribute = "${node.unique.name}"
      operator  = "!="
      value     = "mccoy"
    }

    ephemeral_disk {
      size    = 5000
      migrate = false
      sticky  = false
    }

    network {
      mode = "host"
    }

    restart {
      attempts = 10
      interval = "10m"
      delay    = "30s"
      mode     = "delay"
    }

    # ---------------------------------------------------------------------------
    # Prestart: seed Node 20 so /actions-runner/externals/node20 always exists
    # ---------------------------------------------------------------------------
    task "seed-node20" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image        = "debian:trixie-slim"
        network_mode = "host"
        command      = "bash"
        args = [
          "-lc",
          <<-EOT
            set -euo pipefail
            apt-get update -y
            apt-get install -y --no-install-recommends ca-certificates curl xz-utils
            rm -rf /var/lib/apt/lists/*

            mkdir -p "${NOMAD_ALLOC_DIR}/node20"
            cd "${NOMAD_ALLOC_DIR}/node20"

            ARCH=$(uname -m)
            case "$ARCH" in
              aarch64) NODE_ARCH="arm64" ;;
              arm64)   NODE_ARCH="arm64" ;;
              x86_64)  NODE_ARCH="x64" ;;
              amd64)   NODE_ARCH="x64" ;;
              *) echo "Unknown arch: $ARCH"; exit 1 ;;
            esac

            NODE_VER="v20.18.0"
            TARBALL="node-${NODE_VER}-linux-${NODE_ARCH}.tar.xz"
            URL="https://nodejs.org/dist/${NODE_VER}/${TARBALL}"

            echo "Fetching ${URL}"
            curl -fsSLO "${URL}"
            tar -xJf "${TARBALL}"
            rm -f "${TARBALL}"

            mkdir -p externals/node20
            mv "node-${NODE_VER}-linux-${NODE_ARCH}" externals/node20/node20

            mkdir -p externals/node20/bin
            ln -sf ../node20/bin/node externals/node20/bin/node

            ./externals/node20/bin/node --version
            echo "Node20 preseed complete."
          EOT
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # ---------------------------------------------------------------------------
    # Main runner
    # ---------------------------------------------------------------------------
    task "runner" {
      driver = "docker"

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      config {
        image              = "myoung34/github-runner:debian-trixie"
        image_pull_timeout = "10m"
        network_mode       = "host"
        privileged         = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "${NOMAD_ALLOC_DIR}/node20/externals/node20:/actions-runner/externals/node20"
        ]

        logging {
          type = "journald"
          config {
            tag = "github-runner-${NOMAD_ALLOC_INDEX}"
          }
        }
      }

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

      template {
        destination = "secrets/github.env"
        env         = true
        data        = <<-EOT
          {{ with secret "kv/data/github/runner" }}
          ACCESS_TOKEN="{{ .Data.data.token }}"
          {{ if .Data.data.org_url }}ORG_URL="{{ .Data.data.org_url }}"{{ end }}
          {{ if .Data.data.repo_url }}REPO_URL="{{ .Data.data.repo_url }}"{{ end }}
          {{ if .Data.data.runner_group }}RUNNER_GROUP="{{ .Data.data.runner_group }}"{{ end }}
          {{ end }}

          RUNNER_NAME={{ env "NOMAD_ALLOC_NAME" }}-{{ env "NOMAD_ALLOC_ID" }}
          RUNNER_WORKDIR=/tmp/runner-work
          EPHEMERAL=true

          LABELS=nomad,self-hosted,linux,${attr.cpu.arch},docker

          RUNNER_VERSION=latest
          DISABLE_AUTO_UPDATE=true
        EOT
      }

      env {
        TZ = "America/Los_Angeles"

        START_DOCKER_SERVICE = "false"

        ACTIONS_RUNNER_FORCE_ACTIONS_NODE_VERSION = "node20"
      }

      resources {
        cpu    = 2000
        memory = 2048
      }

      kill_timeout   = "120s"
      kill_signal    = "SIGTERM"
      shutdown_delay = "10s"
    }
  }
}
