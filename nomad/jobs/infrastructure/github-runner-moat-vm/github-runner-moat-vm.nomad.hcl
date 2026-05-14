# -------------------------------------------------------------------------------
# GitHub Actions Runner — moat (VM pool)
#
# Project: Munchbox / Author: Alex Freidah
#
# Sister pool to github-runner-moat. Identical except this pool advertises the
# `vm,kvm` labels and gets /dev/kvm passed into the container so workflows
# requiring real virtualization (Packer-qemu, kitchen-vagrant + vagrant-libvirt,
# load tests) can run natively. Nested virt is already enabled on all amd64
# nomad-client guests — confirmed via `/dev/kvm` + `vmx` flag.
#
# Workflows that need this pool select it via:
#   runs-on: [self-hosted, linux, x64, vm, moat]
#
# Plain CI keeps using the regular pool (no `vm` label).
# -------------------------------------------------------------------------------

job "github-runner-moat-vm" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

  update {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
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
      value     = "stabler.munchbox.cc"
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

    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = true
    }

    service {
      name     = "github-runner-moat-vm"
      provider = "consul"
      task     = "runner"

      tags = [
        "ci",
        "github-actions",
        "runner",
        "moat",
        "vm",
      ]

      check {
        name     = "runner-alive"
        type     = "script"
        command  = "/bin/sh"
        args     = ["-c", "pgrep -f Runner.Listener || pgrep -f run.sh"]
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "runner" {
      driver = "docker"

      vault {
        role        = "nomad-workloads"
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

      template {
        data = <<-EOF
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