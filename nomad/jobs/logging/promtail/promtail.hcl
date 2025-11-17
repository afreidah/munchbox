# -------------------------------------------------------------------------------
# Promtail — Log Collection Agent
#
# Project: Munchbox / Author: Alex Freidah
#
# Collects logs from systemd journal and Nomad allocations, forwarding to Loki
# via Consul Connect service mesh. Uses bridge networking with host volume mounts
# for filesystem access while maintaining zero-trust connectivity.
# -------------------------------------------------------------------------------

job_name        = "promtail"
job_type        = "system"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
node_pool       = "all"
priority        = 50
job_description = "Promtail log collection agent - systemd journal and Nomad allocation logs"

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "monitoring"

resource_tier  = "tiny"
network_preset = "bridge"  # Changed from "host" - required for Connect

ports = [
  {
    name = "http"
    to   = 9080  # Changed from static - bridge mode uses dynamic ports
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

external_files = {
  enabled   = true
  base_path = "jobs/logging/promtail/files"
}

external_templates = [
  {
    destination     = "local/config/config.yaml"
    source_file     = "config.yaml"
    perms           = "0644"
    change_mode     = "restart"
    change_signal   = "SIGTERM"
    left_delimiter  = "[["
    right_delimiter = "]]"
  }
]

task = {
  name   = "promtail"
  driver = "docker"
  config = {
    image = "grafana/promtail:3.5"
    args  = ["-config.file=/etc/promtail/config.yaml"]
    ports = ["http"]
    dns_search_domains = ["service.consul"]
    dns_options        = ["timeout:2", "attempts:3", "ndots:1"]
    volumes = [
      "/var/log/journal:/var/log/journal:ro",
      "/run/log/journal:/run/log/journal:ro",
      "/etc/machine-id:/etc/machine-id:ro",
      "local/config:/etc/promtail:ro",
      "/opt/nomad/alloc:/opt/nomad/alloc:ro",
      "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro"
    ]
  }
  resources = {
    cpu    = 150
    memory = 128
  }
  env = {
    TZ = "America/Los_Angeles"
  }
}

# --- Consul Connect configuration ---
consul_connect_enabled = true

connect_upstreams = [
  {
    destination_name = "loki"
    local_bind_port  = 3100
  }
]

use_node_hostname = true

standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 9080
standard_http_check_enabled  = true
standard_http_check_path     = "/ready"
additional_tags              = ["logging", "promtail", "metrics"]

kill_timeout = "30s"
kill_signal  = "SIGTERM"
