# -------------------------------------------------------------------------------
# traefik-log-dashboard -- Traefik access-log analytics UI
#
# Project: Munchbox / Author: Alex Freidah
#
# One dashboard for the whole ingress pair. It holds no logs itself: each
# ingress node runs a traefik-log-agent alongside its Traefik (in the traefik
# system job, where it can reach that node's access log through the shared
# alloc dir), and this queries both over HTTP.
#
# Single instance on purpose. The agents are per-node and not interchangeable
# -- the VRRP master serves nearly all traffic and the backup almost none -- so
# a load-balanced pair of dashboards hands out whichever node the request
# happened to land on.
# -------------------------------------------------------------------------------

variable "agent_goren" {
  type        = string
  description = "log-agent on goren"
  default     = "http://192.168.68.60:5000"
}

variable "agent_nc05" {
  type        = string
  description = "log-agent on nomad-client-05"
  default     = "http://192.168.68.74:5000"
}

job "traefik-log-dashboard" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 40

  meta = {
    project = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Placement -- an observability UI, so keep it off the ingress nodes it
  # reports on and off the GPU/media node.
  # ---------------------------------------------------------------------------

  constraint {
    attribute = meta.role
    operator  = "!="
    value     = "ingress"
  }

  constraint {
    attribute = meta.cloud
    operator  = "!="
    value     = "oracle"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    canary            = 1
    auto_promote      = true
    auto_revert       = true
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
  }

  # ---------------------------------------------------------------------------
  # Task Group: dashboard
  # ---------------------------------------------------------------------------

  group "dashboard" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    # --- Keeps the dashboard's sqlite DB across restarts on the same node.
    #     The agent list comes from env, but alert rules and UI state live
    #     here. ---
    ephemeral_disk {
      sticky  = true
      migrate = true
      size    = 300
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    service {
      name     = "traefik-log-dashboard"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router (LAN)
        "traefik.http.routers.traefik-logs.rule=Host(`traefik-logs.munchbox.cc`)",
        "traefik.http.routers.traefik-logs.entrypoints=websecure",
        "traefik.http.routers.traefik-logs.tls=true",
        "traefik.http.routers.traefik-logs.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file,dashboard-allowlan@file",
        # Streaming service: keep the live-update stream from being idle-reaped
        "traefik.http.services.traefik-log-dashboard.loadbalancer.serverstransport=streaming@file",
        "traefik.http.services.traefik-log-dashboard.loadbalancer.responseforwarding.flushinterval=100ms",
        # HTTP router (CF tunnel)
        "traefik.http.routers.traefik-logs-http.rule=Host(`traefik-logs.munchbox.cc`)",
        "traefik.http.routers.traefik-logs-http.entrypoints=web",
        "traefik.http.routers.traefik-logs-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
      ]

      check {
        name      = "traefik-log-dashboard-health"
        type      = "http"
        path      = "/"
        interval  = "30s"
        timeout   = "5s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: geoip-updater (prestart)
    #
    # Downloads the MaxMind GeoLite2 databases the dashboard resolves client
    # IPs against. Runs here rather than on the ingress nodes because the
    # dashboard is the only consumer, and it reads the file out of its own
    # alloc dir.
    # -------------------------------------------------------------------------

    task "geoip-updater" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

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
        image = "maxmindinc/geoipupdate:v7"
      }

      template {
        destination = "secrets/geoip.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/maxmind" }}
GEOIPUPDATE_ACCOUNT_ID={{ .Data.data.account_id }}
GEOIPUPDATE_LICENSE_KEY={{ .Data.data.license_key }}
{{ end }}
GEOIPUPDATE_EDITION_IDS=GeoLite2-City GeoLite2-Country
GEOIPUPDATE_DB_DIR=/alloc/data
EOH
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # -------------------------------------------------------------------------
    # Task: dashboard
    # -------------------------------------------------------------------------

    task "dashboard" {
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
        image              = "hhftechnology/traefik-log-dashboard:3.1.1"
        image_pull_timeout = "10m"
        ports              = ["http"]
      }

      # --- Both agents are declared here rather than added through the UI, so
      #     the set is reproducible and survives a rescheduled alloc.
      #     AGENTS_ENV_ONLY stops the UI from adding others that would then
      #     disappear on the next deploy.
      #
      #     The indexed AGENT_<n>_* form is used over DASHBOARD_AGENTS_JSON
      #     because Nomad's env template parser strips double quotes out of
      #     values, which leaves the JSON unparseable by the time it reaches
      #     the process. These are plain scalars with nothing to strip. ---
      template {
        destination = "secrets/dashboard.env"
        env         = true
        data        = <<EOH
{{ with secret "secret/data/traefik-log-dashboard" }}
AGENT_1_TOKEN={{ .Data.data.auth_token }}
AGENT_2_TOKEN={{ .Data.data.auth_token }}
{{ end }}
AGENT_1_ID=goren
AGENT_1_NAME=goren
AGENT_1_URL=${var.agent_goren}
AGENT_1_TAGS=ingress
AGENT_2_ID=nomad-client-05
AGENT_2_NAME=nomad-client-05
AGENT_2_URL=${var.agent_nc05}
AGENT_2_TAGS=ingress
DASHBOARD_AGENTS_ENV_ONLY=true
DASHBOARD_DEFAULT_AGENT_URL=${var.agent_goren}
PORT=3000
DATA_DIR=/alloc/data
GEOIP_LOCAL_DB_PATH=/alloc/data/GeoLite2-City.mmdb
EOH
      }

      resources {
        cpu    = 150
        memory = 192
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
