# -------------------------------------------------------------------------------
# GitHub Actions Runner — moat (VM pool, on-demand)
#
# Project: Munchbox / Author: Alex Freidah
#
# Sister pool to github-runner-moat, parameterized the same way. Identical except
# this pool advertises the `vm,kvm` labels and gets /dev/kvm passed into the
# container so workflows requiring real virtualization (Packer-qemu,
# kitchen-vagrant + vagrant-libvirt, load tests) can run natively. Nested virt is
# already enabled on all amd64 nomad-client guests -- confirmed via `/dev/kvm` +
# `vmx` flag.
#
# Dispatched on demand by the Temporal ci-runner-scaler: a queued moat job whose
# runs-on carries `vm` matches this pool (the scaler's profile list checks `vm`
# before `moat`, so a job asking for both lands here, not on the plain pool).
# Self-registers from the same Vault PAT as the standard pool -- moat isn't ours,
# so no App token is minted; see github-runner-moat for the credential model.
#
# Workflows select this pool via:
#   runs-on: [self-hosted, linux, x64, vm, moat]
#
# Plain CI keeps using the regular pool (no `vm` label).
#
#   nomad job run github-runner-moat-vm.nomad.hcl   # register the parameterized job
#   nomad job dispatch \                             # spawn one runner (scaler does this)
#     -meta repo_url=https://github.com/ev-the-dev/moat \
#     -meta labels=self-hosted,vm,moat \
#     github-runner-moat-vm
# -------------------------------------------------------------------------------

job "github-runner-moat-vm" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "default"

  # --- Dispatched per queued moat vm job; all meta is bookkeeping for the
  #     scaler, so it is optional -- the credential comes from Vault below. ---
  parameterized {
    # runner_secret is permitted but unused: the scaler sends it on every
    # vault-mode dispatch; this job reads its own secret/data/github/moat-runner.
    meta_optional = ["repo_url", "labels", "runner_token", "runner_secret"]
  }

  group "runner" {
    count = 1

    # Exclude the arm64 bare metal Pi5s — moat CI is amd64.
    constraint {
      attribute = "${node.unique.name}"
      operator  = "!="
      value     = "goren"
    }

    constraint {
      attribute = "${node.unique.name}"
      operator  = "!="
      value     = "stabler"
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

    task "runner" {
      driver = "docker"

      vault {
        role        = "github-runner-moat-vm"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image          = "registry.munchbox.cc/moat-runner-vm:1.0.3"
        privileged     = true
        cpu_hard_limit = true

        # /dev/kvm gives the container native KVM acceleration. /dev/net/tun is
        # needed for libvirt/vagrant networks. Both clients have nested virt
        # enabled at the Proxmox layer.
        devices = [
          {
            host_path          = "/dev/kvm"
            container_path     = "/dev/kvm"
            cgroup_permissions = "rwm"
          },
          {
            host_path          = "/dev/net/tun"
            container_path     = "/dev/net/tun"
            cgroup_permissions = "rwm"
          },
        ]

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
RUNNER_NAME=moat-runner-vm-{{ env "NOMAD_ALLOC_ID" }}
RUNNER_WORKDIR=/tmp/runner-work
RUNNER_SCOPE=repo
EPHEMERAL=true
LABELS=nomad,self-hosted,linux,x64,docker,kvm,vm
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
        memory = 4512
      }

      kill_timeout = "120s"
      kill_signal  = "SIGTERM"
    }
  }
}
