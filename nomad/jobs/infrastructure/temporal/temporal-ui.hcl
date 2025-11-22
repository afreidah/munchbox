# -------------------------------------------------------------------------------
# Temporal Web UI — Workflow Monitoring and Management Console
#
# Project: Munchbox / Author: Alex Freidah
#
# Web-based interface for Temporal workflow monitoring and management. Connects
# to Temporal server gRPC API via Consul Connect mesh. Exposed via Traefik for
# browser access with bridge networking.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "temporal-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal UI with Connect mesh access to temporal-server gRPC"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "orchestration"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "bridge"

ports = [
  {
    name = "http"
    to   = 8080
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "stabler"
  }
]

# --- Restart policy ---
restart_attempts = 5
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Task definition ---
task = {
  name   = "ui"
  driver = "docker"

  config = {
    image              = "temporalio/ui:2.31.1"
    image_pull_timeout = "10m"
    ports              = ["http"]
  }

  env = {
    TZ                                    = "UTC"
    TEMPORAL_ADDRESS                      = "temporal-server.service.consul:7233"
    TEMPORAL_CORS_ORIGINS                 = "http://localhost:8080"
    TEMPORAL_CSRF_COOKIE_INSECURE         = "true"
    TEMPORAL_TLS_CA_PATH                  = ""
    TEMPORAL_TLS_CERT_PATH                = ""
    TEMPORAL_TLS_KEY_PATH                 = ""
    TEMPORAL_TLS_ENABLE_HOST_VERIFICATION = "false"
    TEMPORAL_TLS_SERVER_NAME              = ""
  }

  resources = {
    cpu    = 200
    memory = 256
  }
}

# --- Consul Connect service mesh ---
consul_connect_enabled = false

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 8080
standard_http_check_enabled  = true
standard_http_check_path     = "/"

additional_tags = [
  "temporal",
  "ui",
  "monitoring"
]

# --- Traefik routing ---
traefik_enabled     = true
traefik_host        = "temporal.munchbox"
traefik_entrypoints = "websecure"
traefik_tls_enabled = true
traefik_middlewares = "dashboard-allowlan@file"

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
