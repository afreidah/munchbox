# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Nginx Resume static site serving with public and internal access
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Job Configuration
# -----------------------------------------------------------------------

job_name        = "nginx-resume-hostfile"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Static resume site with Nginx and rate limiting"

# -----------------------------------------------------------------------
# Deployment Profile & Metadata
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "standard"
category           = "web"

# -----------------------------------------------------------------------
# Restart Behavior
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# -----------------------------------------------------------------------
# Reschedule Policy
# -----------------------------------------------------------------------

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Resource Tier & Network Configuration
# -----------------------------------------------------------------------

resource_tier  = "small"
network_preset = "bridge"
dns_servers    = ["192.168.68.62", "192.168.68.64"]

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# -----------------------------------------------------------------------
# Storage Configuration
# -----------------------------------------------------------------------

volume = {
  name       = "site"
  type       = "host"
  source     = "nginx-resume"
  read_only  = true
  mount_path = "/usr/share/nginx/html"
}

# -----------------------------------------------------------------------
# Network Ports
# -----------------------------------------------------------------------

ports = [
  {
    name   = "http"
    static = 8080
    port   = 80
  }
]

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

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

  templates = [
    {
      destination = "local/default.conf"
      change_mode = "signal"
      change_signal = "SIGHUP"
      data = <<-EOF
limit_req_zone  $binary_remote_addr  zone=resume_req_zone:10m  rate=10r/s;
limit_conn_zone $binary_remote_addr  zone=resume_conn_zone:10m;

server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;

  index resume.html index.html;

  limit_conn resume_conn_zone 20;

  location / {
    try_files $uri $uri/ /resume.html;
    limit_req zone=resume_req_zone burst=20 nodelay;
  }
}
EOF
    }
  ]

  service = {
    name = "nginx-resume"
    port = "http"
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
