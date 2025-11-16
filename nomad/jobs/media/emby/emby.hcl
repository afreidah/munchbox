# -------------------------------------------------------------------------------
# Emby Media Server — Streaming Platform with Hardware Transcoding Support
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "emby"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Emby media server with GPU transcoding and library management"

deployment_profile = "standard"
meta_profile       = "tier1"
category           = "media"

resource_tier  = "large"
network_preset = "host"

ports = [
  {
    name   = "web"
    static = 8096
  },
  {
    name   = "https"
    static = 8920
  }
]

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

task = {
  name   = "emby"
  driver = "docker"
  config = {
    image              = "linuxserver/emby:latest"
    image_pull_timeout = "10m"
    ports              = ["web", "https"]
    devices = [
      {
        host_path          = "/dev/dri"
        container_path     = "/dev/dri"
        cgroup_permissions = "rwm"
      }
    ]
    volumes = [
      "/opt/nomad/data/emby/config:/config",
      "/opt/nomad/data/emby/cache:/cache",
      "/opt/nomad/data/emby/transcode:/transcode",
      "/mnt/gdrive/media/Movies:/media/Movies:ro",
      "/mnt/gdrive/media/TV:/media/TV:ro",
      "/mnt/gdrive/media/Music:/media/Music:ro",
      "/mnt/gdrive/media/Books:/media/Books:ro",
      "/mnt/gdrive/media/ISOs:/media/ISOs:ro",
      "/mnt/gdrive/media/Software:/media/Software:ro",
      "/mnt/gdrive/media/hacker-magazines:/media/hacker-magazines:ro",
      "/mnt/gdrive/media/random:/media/random:ro",
      "/mnt/gdrive/media/taxes:/media/taxes:ro"
    ]
  }
  env = {
    PUID = "1001"
    PGID = "1001"
    TZ   = "UTC"
  }
  resources = {
    cpu    = 2000
    memory = 4096
  }
}

standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 8096
standard_http_check_enabled  = true
standard_http_check_path     = "/"
additional_tags              = ["media", "emby", "streaming"]

kill_timeout = "30s"
kill_signal  = "SIGTERM"
