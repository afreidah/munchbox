# -------------------------------------------------------------------------------
# Nginx Resume — Static Site Serving
#
# Project: Munchbox / Author: Alex Freidah
#
# Static resume site with Nginx and rate limiting. Dual routing: public access
# via alexfreidah.com and internal access via resume.munchbox.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "nginx-resume-hostfile"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
count           = 1
job_description = "Static resume site with Nginx and rate limiting"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "web"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "bridge"
dns_servers    = ["192.168.68.62", "192.168.68.64"]

ports = [
  {
    name = "http"
    to   = 80
  }
]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# --- Persistent storage volume ---
volume = {
  name       = "site"
  type       = "host"
  source     = "nginx-resume"
  mount_path = "/usr/share/nginx/html"
  read_only  = true
}

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/web/nginx-resume/files"
}

external_templates = [
  {
    destination   = "local/default.conf"
    source_file   = "nginx.conf"
    env           = false
    perms         = "0644"
    change_mode   = "signal"
    change_signal = "SIGHUP"
  }
]

# --- Task definition ---
task = {
  name   = "nginx"
  driver = "docker"

  config = {
    image = "nginx:stable"
    ports = ["http"]
    volumes = [
      "local/default.conf:/etc/nginx/conf.d/default.conf:ro"
    ]
  }

  service = {
    name = "nginx-resume"
    port = "http"
    provider = "consul"
    tags = [
      "traefik.enable=true",
      "traefik.http.routers.resume-public.rule=Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)",
      "traefik.http.routers.resume-public.entrypoints=web",
      "traefik.http.routers.resume-public.service=nginx-resume",
      "traefik.http.services.nginx-resume.loadbalancer.server.port=8080",
      "traefik.http.routers.resume-internal.rule=Host(`resume.munchbox`)",
      "traefik.http.routers.resume-internal.entrypoints=websecure",
      "traefik.http.routers.resume-internal.tls=true",
      "traefik.http.routers.resume-internal.middlewares=dashboard-allowlan@file",
      "web",
      "resume",
      "nginx"
    ]
    checks = [
      {
        name     = "nginx-resume"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    ]
  }

  resources = {
    cpu    = 200
    memory = 128
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
