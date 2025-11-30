# -------------------------------------------------------------------------------
# Nginx Resume — Static Site Serving
#
# Project: Munchbox / Author: Alex Freidah
#
# Static resume site served from custom Docker image. Dual routing: public
# access via alexfreidah.com and internal access via resume.munchbox.cc.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "nginx-resume"
type  = "service"
image = "registry.munchbox.cc/alex-resume:latest"
port  = 80
host_network = false
node  = "nomad-client-02"
size = "small"
storage = "ephemeral"

# --- Traefik integration ---
traefik = false
health_path = "/"

# --- Service tags (completely custom routers) ---
tags = [
  "web",
  "resume",
  "nginx",
  "traefik.enable=true",
  "traefik.http.routers.resume-public.rule=Host(`resume.alexfreidah.com`) || Host(`www.resume.alexfreidah.com`)",
  "traefik.http.routers.resume-public.entrypoints=web",
  "traefik.http.routers.resume-public.middlewares=redirect-resume-www@file,resume-sec@file,resume-ratelimit@file",
  "traefik.http.routers.resume-public.priority=100",
  "traefik.http.routers.resume-apex.rule=Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)",
  "traefik.http.routers.resume-apex.entrypoints=web",
  "traefik.http.routers.resume-apex.middlewares=redirect-apex-to-resume@file,resume-sec@file",
  "traefik.http.routers.resume-apex.priority=101"
]
