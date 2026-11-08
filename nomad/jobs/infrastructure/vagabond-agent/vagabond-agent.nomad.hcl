# -------------------------------------------------------------------------------
# vagabond-agent - Homelab node for the Vagabond homelab pool
#
# Project: Munchbox / Author: Alex Freidah
#
# Joins the server's homelab pool and runs its workloads on the host's
# containerd, inside this task's cgroup, so Nomad's reservation is what the pool
# offers. Dials vagabond.service.consul:4748 over mutual TLS with a cert from
# pki_vagabond; the cert's common name is the node name, and the
# vagabond-agent role only issues the names it lists.
#
# Workloads run as root on the host network, so it stays off ingress nodes.
# -------------------------------------------------------------------------------

# --- Set by make run from Consul KV deploy/versions/vagabond-agent. Its own key,
#     so a server release doesn't restart the agent under running workloads. ---
variable "vagabond_agent_version" {
  type = string
}

job "vagabond-agent" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

  # --- The one node the vagabond-agent PKI role issues a name for ---
  constraint {
    attribute = "${node.unique.name}"
    value     = "nomad-client-04"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  # --- No canary: a second agent under the same name replaces the first ---
  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: agent
  # ---------------------------------------------------------------------------

  group "agent" {
    count = 1

    # --- Network Configuration: the agent dials out and listens on nothing ---
    network {
      mode = "host"
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -------------------------------------------------------------------------
    # Task: agent
    # -------------------------------------------------------------------------

    task "agent" {
      driver = "docker"

      # --- The image defaults to appuser; containerd's socket needs root ---
      user = "root"

      vault {
        role        = "vagabond-agent"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- privileged and the host cgroup namespace let the agent create its
      #     workloads' cgroups under its own; cpu_hard_limit turns the cpu
      #     reservation into the cpu.max the agent reads as capacity. The data
      #     dir has the same path inside and out, because containerd resolves
      #     the log mounts on the host. ---
      config {
        image              = "registry.munchbox.cc/vagabond:${var.vagabond_agent_version}"
        image_pull_timeout = "10m"
        network_mode       = "host"
        privileged         = true
        cgroupns           = "host"
        cpu_hard_limit     = true

        args = [
          "agent",
          "-server", "vagabond.service.consul:4748",
          "-pool", "homelab",
          "-tls-ca", "/secrets/ca.pem",
          "-tls-cert", "/secrets/agent.pem",
          "-tls-key", "/secrets/agent-key.pem",
        ]

        volumes = [
          "/run/containerd/containerd.sock:/run/containerd/containerd.sock",
          "/var/lib/vagabond:/var/lib/vagabond",
        ]
      }

      # --- Cert, key and CA: one issue call, since the args match. Read only
      #     at startup, so a renewal restarts the task. ---
      template {
        data        = <<EOH
{{ with secret "pki_vagabond/issue/vagabond-agent" (printf "common_name=%s" (env "node.unique.name")) "ttl=2160h" }}{{ .Data.certificate }}{{ end }}
EOH
        destination = "secrets/agent.pem"
        change_mode = "restart"
        perms       = "0400"
      }

      template {
        data        = <<EOH
{{ with secret "pki_vagabond/issue/vagabond-agent" (printf "common_name=%s" (env "node.unique.name")) "ttl=2160h" }}{{ .Data.private_key }}{{ end }}
EOH
        destination = "secrets/agent-key.pem"
        change_mode = "restart"
        perms       = "0400"
      }

      template {
        data        = <<EOH
{{ with secret "pki_vagabond/issue/vagabond-agent" (printf "common_name=%s" (env "node.unique.name")) "ttl=2160h" }}{{ .Data.issuing_ca }}{{ end }}
EOH
        destination = "secrets/ca.pem"
        change_mode = "restart"
        perms       = "0400"
      }

      # --- One static-analysis slot (2000m, 4096 MiB) plus the agent itself.
      #     Check cpu= in the agent's startup log: the MHz-to-cores
      #     conversion decides whether a 2000m workload fits. ---
      resources {
        cpu    = 5000
        memory = 4608
      }

      # --- Termination ---
      kill_timeout = "15s"
      kill_signal  = "SIGTERM"
    }
  }
}
