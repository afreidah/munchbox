# -------------------------------------------------------------------------------
# nginx-resume — Static Resume Site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves static resume website on resume.alexfreidah.com.
# Apex domain (alexfreidah.com) is handled by the personal-site job.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "nginx-resume"
type  = "service"
image = "registry.munchbox.cc/alex-resume:v0.0.1"
port  = 80
node  = "any"
host_network = false
size  = "tiny"
count = 3
storage = "ephemeral"

# --- Placement: one instance per node ---
constraints = [
  { attribute = "", operator = "distinct_hosts", value = "true" }
]

# --- Vault integration ---
vault = false

# --- Traefik integration ---
traefik = true
health_path = "/"

# --- Service tags (custom routing via cloudflared) ---
tags = [
  "web",
  "nginx",
  "static",
  # Resume subdomain
  "traefik.http.routers.resume-public.rule=Host(`resume.alexfreidah.com`) || Host(`www.resume.alexfreidah.com`)",
  "traefik.http.routers.resume-public.entrypoints=web",
  "traefik.http.routers.resume-public.service=nginx-resume",
  "traefik.http.routers.resume-public.middlewares=redirect-resume-www@file,resume-sec@file,resume-ratelimit@file",
  "traefik.http.routers.resume-public.priority=100",
]
