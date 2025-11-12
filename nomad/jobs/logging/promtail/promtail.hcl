# -------------------------------------------------------------------------------
# Promtail job
#
# Uses the nomad-service pack; inherits monitoring defaults (http port, small tier)
# and a generated HTTP check. Only image/args/volumes and config template remain.
# -------------------------------------------------------------------------------

pack {
  name = "nomad-service"
}

variables = {
  job_name = "promtail"
  category = "monitoring"

  # Generated service + /ready check
  standard_http_check_enabled = true
  standard_http_check_path    = "/ready"

  # Inject static config from local file
  external_files = {
    enabled   = true
    base_path = "jobs/logging/promtail/files"
  }
  external_templates = [
    {
      destination   = "/etc/promtail/config.yml"
      source_file   = "config.yaml"
      env           = false
      perms         = "0644"
      change_mode   = "restart"
      change_signal = "SIGTERM"
    }
  ]

  task = {
    name   = "promtail"
    driver = "docker"
    config = {
      image = "grafana/promtail:2.9.4"
      args  = ["-config.file=/etc/promtail/config.yml"]

      # Host mounts required by your config.yaml scrape paths
      volumes = [
        "/var/log:/var/log:ro",
        "/run/log/journal:/run/log/journal:ro",
        "/var/log/journal:/var/log/journal:ro",
        "/var/lib/docker/containers:/var/lib/docker/containers:ro",
        "/opt/nomad/alloc:/opt/nomad/alloc:ro",
        "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro"
      ]
    }
  }
}

