# -------------------------------------------------------------------------------
# vagabond - Compute broker server
#
# Project: Munchbox / Author: Alex Freidah
#
# Dispatches stateless CI jobs to Cloud Run. State lives in Postgres. The API has
# no authentication, so it stays on the LAN: no Traefik route. Agents are not
# used yet, so the agent listener keeps its loopback default.
#
# The job name is what grants secret/vagabond/*, through nomad-workload-self.
# -------------------------------------------------------------------------------

# --- Set by make run from Consul KV deploy/versions/ ---
variable "vagabond_version" {
  type = string
}

job "vagabond" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  # --- No canary: migrations take no lock, so two servers must not start at once ---
  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: vagabond
  # ---------------------------------------------------------------------------

  group "vagabond" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 4747
      }
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

    # --- Service Registration ---
    service {
      name     = "vagabond"
      port     = "http"
      provider = "consul"

      check {
        type     = "http"
        path     = "/v1/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: vagabond
    # -------------------------------------------------------------------------

    task "vagabond" {
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
        image              = "registry.munchbox.cc/vagabond:${var.vagabond_version}"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"
        args               = ["server", "-config", "/secrets/config.hcl"]
      }

      # --- Configuration rendered by Vault; uid is the image's appuser ---
      template {
        data        = <<EOH
server {
  bind = "0.0.0.0:4747"
}

{{ with secret "secret/data/vagabond/postgres" }}
store {
  dsn = "postgres://{{ .Data.data.db_username }}:{{ .Data.data.db_password }}@haproxy-postgres.service.consul:5433/vagabond?sslmode=require&target_session_attrs=read-write"
}
{{ end }}

{{ with secret "secret/data/vagabond/cloud-run" }}
provider "gcp-cloud-run" {
  type = "cloud-run"

  config {
    project                 = "{{ .Data.data.project }}"
    region                  = "{{ .Data.data.region }}"
    runtime_service_account = "{{ .Data.data.runtime_account_email }}"
  }

  credentials {
    file = "/secrets/gcp-dispatcher.json"
  }

  # 80% of the free tier for Jobs: 240,000 vCPU-seconds and 450,000 GiB-seconds.
  pool "cpu" {
    meter  = "cpu_seconds"
    limit  = 192000
    period = "monthly"
  }

  pool "memory" {
    meter  = "gb_seconds"
    limit  = 360000
    period = "monthly"
  }
}
{{ end }}
EOH
        destination = "secrets/config.hcl"
        change_mode = "restart"
        uid         = 10001
        gid         = 10001
        perms       = "0400"
      }

      # --- The dispatcher key; the image has no vault CLI for an exec credential ---
      template {
        data        = <<EOH
{{ with secret "secret/data/vagabond/cloud-run" }}{{ .Data.data.credentials_json }}{{ end }}
EOH
        destination = "secrets/gcp-dispatcher.json"
        change_mode = "restart"
        uid         = 10001
        gid         = 10001
        perms       = "0400"
      }

      # --- Resources ---
      resources {
        cpu        = 200
        memory     = 128
        memory_max = 256
      }

      # --- Termination: the server drains HTTP requests for up to 10s ---
      kill_timeout = "15s"
      kill_signal  = "SIGTERM"
    }
  }
}
