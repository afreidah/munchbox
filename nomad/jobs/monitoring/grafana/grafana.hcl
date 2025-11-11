# jobs/monitoring/grafana/grafana.hcl

job_name         = "grafana"
region           = "global"
datacenters      = ["pi-dc"]
node_pool        = "edge"
resource_tier    = "small"
deployment_profile = "canary"

# -----------------------------------------------------------------------
# External File Configuration
# -----------------------------------------------------------------------

external_files = {
  enabled   = true
  base_path = "jobs/monitoring/grafana/files"
}

external_templates = [
  {
    destination     = "secrets/grafana.env"
    source_file     = "grafana.env.tpl"
    env             = true
    perms           = "0600"
    change_mode     = "restart"
    change_signal   = ""
    left_delimiter  = "{{{"
    right_delimiter = "}}}"
  },
  {
    destination     = "local/grafana-provisioning/datasources/ds.yml"
    source_file     = "datasources.yml"
    env             = false
    perms           = "0644"
    change_mode     = "restart"
    change_signal   = ""
    left_delimiter  = ""
    right_delimiter = ""
  }
]

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "grafana"
  driver = "docker"
  
  config = {
    image              = "grafana/grafana:12.2.0"
    ports              = ["web"]
    network_mode       = "host"
    dns_servers        = ["192.168.68.62", "192.168.68.64"]
    dns_search_domains = ["service.consul"]
    volumes = [
      "local/grafana-provisioning:/etc/grafana/provisioning"
    ]
  }

  env = {
    GF_SERVER_ROOT_URL = "https://grafana.munchbox/"
  }
}

ports = [
  {
    name   = "web"
    static = 3000
    port   = 3000
  }
]

volume = {
  name       = "grafana-data"
  type       = "host"
  source     = "grafana-data"
  mount_path = "/var/lib/grafana"
  read_only  = false
}
