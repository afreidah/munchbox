# -------------------------------------------------------------------------------
# nginx-resume — Static Resume Site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves static resume website with custom routing for both resume subdomain
# and apex domain, all redirecting to canonical resume.alexfreidah.com.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "nginx-resume"
type  = "service"
image = "registry.munchbox.cc/alex-resume:latest"
port  = 80
size  = "tiny"
storage = "ephemeral"

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
  "traefik.http.routers.resume-public.service=nginx-resume",  # ← ADD THIS
  "traefik.http.routers.resume-public.middlewares=redirect-resume-www@file,resume-sec@file,resume-ratelimit@file",
  "traefik.http.routers.resume-public.priority=100",
  # Apex domain
  "traefik.http.routers.resume-apex.rule=Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)",
  "traefik.http.routers.resume-apex.entrypoints=web",
  "traefik.http.routers.resume-apex.service=nginx-resume",  # ← ADD THIS
  "traefik.http.routers.resume-apex.middlewares=redirect-apex-to-resume@file,resume-sec@file",
  "traefik.http.routers.resume-apex.priority=101",
]
