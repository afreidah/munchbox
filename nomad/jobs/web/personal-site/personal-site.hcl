# -------------------------------------------------------------------------------
# personal-site — Landing Page for alexfreidah.com
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the personal landing page. Public-facing via Cloudflare tunnel.
# Replaces the previous apex domain redirect to resume.alexfreidah.com.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "personal-site"
type  = "service"
image = "registry.munchbox.cc/personal-site:v0.0.2"
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

# --- Service tags ---
tags = [
  "web",
  "personal",
  "traefik.http.routers.alex-web.rule=Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)",
  "traefik.http.routers.alex-web.entrypoints=web",
  "traefik.http.routers.alex-web.service=personal-site",
  "traefik.http.routers.alex-web.middlewares=resume-sec@file,umami-tracking@file",
  "traefik.http.routers.alex-web.priority=101",
]
