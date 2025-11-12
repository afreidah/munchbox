# defaults.hcl
# -------------------------------------------------------------------------------
# Shared defaults and registry for nomad-service pack
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Global defaults
# -----------------------------------------------------------------------

namespace          = "default"
deployment_profile = "standard"
meta_profile       = "tier3"
resource_tier      = "small"
network_preset     = "bridge"
dns_servers        = ["192.168.68.62", "192.168.68.64"]

# Optional environment overlay
environment = ""  # dev | home | prod
env_defaults = {
  dev = {
    namespace   = "default"
    datacenters = ["pi-dc"]
  }
  home = {
    namespace   = "default"
    datacenters = ["pi-dc"]
  }
  prod = {
    namespace   = "default"
    datacenters = ["pi-dc"]
  }
}

# -----------------------------------------------------------------------
# Component registry — define each service once here
# -----------------------------------------------------------------------

component_registry = {

  promtail = {
    job_type = "system"

    ports = [{ name = "http" }]

    standard_http_check_enabled = true
    standard_http_check_port    = "http"
    standard_http_check_path    = "/ready"
    standard_service_name       = "promtail"

    external_files = {
      enabled   = true
      base_path = "jobs/logging/promtail/files"
    }

    external_templates = [
      {
        destination   = "/etc/promtail/config.yml"
        source_file   = "config.yaml"
        env           = false
        perms         = "0644"
        change_mode   = "restart"
        change_signal = "SIGTERM"
      }
    ]

    task = {
      name   = "promtail"
      driver = "docker"
      config = {
        image   = "grafana/promtail:2.9.4"
        args    = ["-config.file=/etc/promtail/config.yml"]
        ports   = ["http"]
        volumes = [
          "/var/log:/var/log:ro",
          "/run/log/journal:/run/log/journal:ro",
          "/var/log/journal:/var/log/journal:ro",
          "/var/lib/docker/containers:/var/lib/docker/containers:ro",
          "/opt/nomad/alloc:/opt/nomad/alloc:ro",
          "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro"
        ]
      }
      resources = { tier = "small" }
    }
  }

  loki = {
    ports = [{ name = "http" }]
    standard_http_check_enabled = true
    standard_http_check_path    = "/ready"
    standard_service_name       = "loki"
    task = {
      name   = "loki"
      driver = "docker"
      config = {
        image = "grafana/loki:2.9.4"
        ports = ["http"]
      }
      resources = { tier = "medium" }
    }
  }

  traefik = {
    ports = [{ name = "web" }, { name = "websecure" }]
    standard_http_check_enabled = true
    standard_http_check_port    = "web"
    standard_http_check_path    = "/ping"
    standard_service_name       = "traefik"
    task = {
      name   = "traefik"
      driver = "docker"
      config = {
        image = "traefik:3.0"
        ports = ["web", "websecure"]
      }
      resources = { tier = "small" }
    }
  }

  nginx_resume = {
    ports = [{ name = "http" }]
    standard_http_check_enabled = true
    standard_http_check_path    = "/"
    standard_service_name       = "nginx-resume"

    traefik_enable              = true
    traefik_internal_host       = "resume"
    traefik_internal_entrypoint = "websecure"
    traefik_service_port        = 80

    task = {
      name   = "nginx"
      driver = "docker"
      config = {
        image   = "nginx:1.27-alpine"
        ports   = ["http"]
        volumes = [
          "local/site:/usr/share/nginx/html:ro",
          "local/nginx.conf:/etc/nginx/nginx.conf:ro"
        ]
      }
      resources = { tier = "small" }
    }
  }

  waypoint_server = {
    ports = [{ name = "http" }]
    standard_http_check_enabled = true
    standard_http_check_path    = "/"
    standard_service_name       = "waypoint-server"
    task = {
      name   = "waypoint"
      driver = "docker"
      config = {
        image = "hashicorp/waypoint:latest"
        ports = ["http"]
      }
      resources = { tier = "small" }
    }
  }

  temporal_server = {
    ports = [{ name = "http" }]
    standard_http_check_enabled = true
    standard_http_check_path    = "/"
    standard_service_name       = "temporal-server"
    task = {
      name   = "temporal"
      driver = "docker"
      config = {
        image = "temporalio/server:latest"
        ports = ["http"]
      }
      resources = { tier = "medium" }
    }
  }

  node_exporter = {
    ports = [{ name = "http" }]
    standard_http_check_enabled = true
    standard_http_check_path    = "/metrics"
    standard_service_name       = "node-exporter"
    task = {
      name   = "node-exporter"
      driver = "docker"
      config = {
        image = "quay.io/prometheus/node-exporter:latest"
        ports = ["http"]
      }
      resources = { tier = "tiny" }
    }
  }

  grafana = {
    ports = [{ name = "http" }]
    standard_http_check_enabled = true
    standard_http_check_path    = "/api/health"
    standard_service_name       = "grafana"
    task = {
      name   = "grafana"
      driver = "docker"
      config = {
        image = "grafana/grafana:latest"
        ports = ["http"]
      }
      resources = { tier = "small" }
    }
  }

  prometheus = {
    ports = [{ name = "http" }]
    standard_http_check_enabled = true
    standard_http_check_path    = "/-/ready"
    standard_service_name       = "prometheus"
    task = {
      name   = "prometheus"
      driver = "docker"
      config = {
        image = "prom/prometheus:latest"
        ports = ["http"]
      }
      resources = { tier = "medium" }
    }
  }
}
