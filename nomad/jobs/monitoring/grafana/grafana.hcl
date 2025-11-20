# -------------------------------------------------------------------------------
# Grafana — Monitoring Dashboards and Visualization Service
#
# Project: Munchbox / Author: Alex Freidah
#
# Provides Grafana dashboards with Prometheus and Loki datasource integration
# via Consul Connect service mesh. Upstreams configured for secure mTLS
# communication with data sources.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------

job_name        = "grafana"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
priority        = 50
job_description = "Grafana dashboards with Prometheus and Loki integration"

# -----------------------------------------------------------------------
# Vault Integration
# -----------------------------------------------------------------------

vault_role = "nomad-workloads"

# -----------------------------------------------------------------------
# Deployment Strategy
# -----------------------------------------------------------------------

deployment_profile = "canary"
meta_profile       = "tier1"
category           = "monitoring"

# -----------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------

resource_tier = "small"

# -----------------------------------------------------------------------
# Networking
#
# Consul Connect requires bridge or CNI networking. We run Grafana on
# bridge, and the sidecar handles mesh exposure. Port 3000 is still used
# inside the container and exposed via the "web" label.
# -----------------------------------------------------------------------

network_preset = "bridge"

ports = [
  {
    name = "web"
    to   = 3000
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule Policies
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "fail"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# External Configuration Files
# -----------------------------------------------------------------------

external_files = {
  enabled   = true
  base_path = "jobs/monitoring/grafana/files"
}

external_templates = [
  #{
  #  destination = "local/grafana-provisioning/datasources/ds.yml"
  #  source_file = "datasources.yml"
  #  env         = false
  #  perms       = "0644"
  #  change_mode = "restart"
  #},
  {
    destination = "secrets/grafana.env"
    source_file = "grafana.env.tpl"
    env         = true
    perms       = "0600"
    change_mode = "restart"
  }
]

# -----------------------------------------------------------------------
# Task Definition
# -----------------------------------------------------------------------

task = {
  name   = "grafana"
  driver = "docker"
  user   = "root"

  config = {
    image              = "grafana/grafana:12.2.0"
    ports              = ["web"]
    image_pull_timeout = "10m"
    volumes = [
      "local/grafana-provisioning:/etc/grafana/provisioning",
      "/mnt/gdrive/munchbox-data/grafana:/var/lib/grafana"
    ]
  }

  env = {
    GF_SERVER_SERVE_FROM_SUB_PATH = "false"
    GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
  }
}

# -----------------------------------------------------------------------
# Consul Connect
#
# Grafana participates in the mesh. The Connect sidecar exposes local
# upstreams for Prometheus and Loki, which you should reference from your
# datasources.yml (e.g. http://127.0.0.1:9090, http://127.0.0.1:3100).
# -----------------------------------------------------------------------

consul_connect_enabled = true

connect_upstreams = [
  {
    destination_name = "prometheus"
    local_bind_port  = 9090
  },
  {
    destination_name = "loki"
    local_bind_port  = 3100
  }
]

# -----------------------------------------------------------------------
# Service Registration
# -----------------------------------------------------------------------

standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 3000
standard_http_check_enabled  = true
standard_http_check_path     = "/api/health"

# Classification tags only; Traefik routing is handled via dedicated
# Traefik variables so the pack can place tags on the Connect sidecar.
additional_tags = [
  "monitoring",
  "grafana"
]

# -----------------------------------------------------------------------
# Traefik Routing
#
# These feed into the nomad-service template:
# - With Consul Connect enabled + standard service:
#     Traefik tags are attached to the sidecar service, which Traefik
#     will discover via Consul Catalog (connectAware + connectByDefault).
# -----------------------------------------------------------------------

traefik_enabled         = true
traefik_host            = "grafana.munchbox"
traefik_entrypoints     = "websecure"
traefik_tls_enabled     = true
traefik_middlewares     = "dashboard-allowlan@file"

# -----------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
