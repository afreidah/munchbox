# -------------------------------------------------------------------------------
# ErsatzTV — Virtual TV Channel Engine with Emby Integration
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "ersatztv"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "ErsatzTV virtual TV channel engine with Emby backend"

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "media"

resource_tier  = "medium"
network_preset = "host"

ports = [
  {
    name   = "ui"
    static = 8409
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
  name   = "ersatztv"
  driver = "docker"
  config = {
    image              = "jasongdove/ersatztv:latest"
    image_pull_timeout = "10m"
    ports              = ["ui"]
    volumes = [
      "/opt/nomad/data/ersatztv/config:/config",
      "/opt/nomad/data/ersatztv/transcode:/transcode",
      "/mnt/gdrive/media/Movies:/media/Movies:ro",
      "/mnt/gdrive/media/TV:/media/TV:ro"
    ]
  }
  env = {
    TZ = "UTC"
  }
  resources = {
    cpu    = 500
    memory = 1024
  }
}

standard_service_enabled     = true
standard_service_port        = "ui"
standard_service_port_number = 8409
standard_http_check_enabled  = true
standard_http_check_path     = "/"
additional_tags              = ["media", "ersatztv", "streaming"]

kill_timeout = "30s"
kill_signal  = "SIGTERM"
