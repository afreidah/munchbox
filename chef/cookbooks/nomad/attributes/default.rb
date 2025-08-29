# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Attributes:: default
#
# Default attributes for Nomad installation, configuration, and clustering.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Nomad General
# --------------------------------------------------------------------

default['nomad']['client_tags'] = {}
default['nomad']['group']       = 'root'
default['nomad']['user']        = 'root'
default['nomad']['datacenter']  = 'pi-dc'
default['nomad']['version']     = '1.10.3'
default['nomad']['data_dir']    = '/opt/nomad'
default['nomad']['config_dir']  = '/etc/nomad.d'
default['nomad']['bin_path']    = '/usr/local/bin'
default['nomad']['bind_addr']   = node['ipaddress'] # Override on multihomed hosts

default['nomad']['packages'] = %w(
  default-jre-headless
)

# Identity / logging for clearer UI and diagnostics
default['nomad']['name']      = node['hostname'] # Friendly node name in Nomad UI/logs
default['nomad']['log_level'] = 'INFO'           # INFO for steady state; DEBUG during bring-up

# Explicit advertise override (optional). If nil, template falls back to bind_addr.
default['nomad']['advertise_ip'] = nil

# Gossip (Serf) encryption key for Nomad agent LAN traffic
# Generate with: `nomad operator keygen` and inject via encrypted data bag or roles.
default['nomad']['serf_key'] = '' # DO NOT COMMIT REAL KEYS

default['nomad']['checksums'] = {
  '1.10.3' => {
    'amd64' => 'a161b8d59b42555d97d37f7a75c122831be485e89dfb97d16d6b60cfaec8d88b', # nomad_1.10.3_linux_amd64.zip
    'arm64' => '33d29315154035295a0f735622da4322ea500e49b5f85686139e76a5e89a7ce9', # nomad_1.10.3_linux_arm64.zip
  },
}

# --------------------------------------------------------------------
# Security: TLS (Nomad HTTP/RPC)
# --------------------------------------------------------------------
# Enable HTTPS for API/UI and mTLS for RPC. Provide per-node certs with correct SANs.
default['nomad']['tls']['enabled']              = true
default['nomad']['tls']['ca_file']              = '/opt/nomad/tls/nomad-agent-ca.pem'
default['nomad']['tls']['cert_file']            = '/opt/nomad/tls/global-server-nomad.pem'
default['nomad']['tls']['key_file']             = '/opt/nomad/tls/global-server-nomad-key.pem'
# Optional: require client certs for HTTP API access
default['nomad']['tls']['verify_https_client']  = false

# --------------------------------------------------------------------
# Server Role
# --------------------------------------------------------------------

default['nomad']['server']['enabled']         = true
default['nomad']['server']['raft_multiplier'] = 2
default['nomad']['server']['retry_interval']  = '15s'
default['nomad']['server']['retry_max']       = 5

# Static peer list used for server_join.retry_join (host:4648 will be derived)
default['nomad']['server']['servers'] = %w(
  192.168.68.60
  192.168.68.61
  192.168.68.63
)

# --------------------------------------------------------------------
# Client Role
# --------------------------------------------------------------------

default['nomad']['client']['enabled']    = true
default['nomad']['client']['node_class'] = ''
default['nomad']['client']['cni_path']   = '/usr/sbin'

# Enable raw_exec for small/util tasks even if Docker is primary
default['nomad']['client']['raw_exec']   = true

# Host volumes exposed to jobs (paths are created with permissive mode by default)
default['nomad']['client']['host_volumes'] = [
  { 'name' => 'prometheus', 'path' => '/opt/nomad/data/prometheus', 'read_only' => false },
  { 'name' => 'traefik', 'path' => '/opt/nomad/data/traefik', 'read_only' => true },
  { 'name' => 'registry', 'path' => '/opt/nomad/data/registry', 'read_only' => false },
  { 'name' => 'prometheus-data', 'path' => '/opt/nomad/data/prometheus-data', 'read_only' => false },
  { 'name' => 'registry-data', 'path' => '/opt/nomad/data/registry-data', 'read_only' => false },
  { 'name' => 'registry-ui-conf', 'path' => '/opt/nomad/data/registry-ui-conf', 'read_only' => false },
  { 'name' => 'registry-ui-html', 'path' => '/opt/nomad/data/registry-ui-html', 'read_only' => false },
  { 'name' => 'registry-ui', 'path' => '/opt/nomad/data/registry-ui-data', 'read_only' => false },
  { 'name' => 'grafana-data', 'path' => '/opt/nomad/data/grafana-data', 'read_only' => false }
]

# --------------------------------------------------------------------
# Docker Task Driver
# --------------------------------------------------------------------

default['nomad']['docker']['allow_privileged']   = true
default['nomad']['docker']['volumes']['enabled'] = true
default['nomad']['docker']['caps']               = %w(
  NET_ADMIN
  NET_BIND_SERVICE
)
# Optional: non-default Docker socket path (template only emits if set)
default['nomad']['docker']['socket']             = '/var/run/docker.sock'

# --------------------------------------------------------------------
# Telemetry
# --------------------------------------------------------------------

default['nomad']['telemetry']['enabled']                     = true
default['nomad']['telemetry']['collection_interval']         = '1s'
default['nomad']['telemetry']['disable_hostname']            = true
default['nomad']['telemetry']['prometheus_metrics']          = true
default['nomad']['telemetry']['publish_allocation_metrics']  = true
default['nomad']['telemetry']['publish_node_metrics']        = true

# --------------------------------------------------------------------
# Consul Integration
# --------------------------------------------------------------------

default['nomad']['consul']['auto_advertise'] = true
default['nomad']['consul']['auto_join']      = true
default['nomad']['consul']['enabled']        = true
default['nomad']['consul']['address']        = "#{node['ipaddress']}:8500"
default['nomad']['consul']['required']       = true # Cluster resource will wait for Consul if true

# --------------------------------------------------------------------
# CNI Plugins
# --------------------------------------------------------------------

default['nomad']['cni']['version']  = 'v1.6.2'
default['nomad']['cni']['path']     = '/opt/cni/bin'
default['nomad']['cni']['url']      = 'https://github.com/containernetworking/plugins/releases/download'
default['nomad']['cni']['enable']   = true

# --------------------------------------------------------------------
# Vault Integration
# --------------------------------------------------------------------

default['nomad']['vault']['enabled'] = true
default['nomad']['vault']['address'] = 'http://mccoy:8200'
# Token is sourced from encrypted data bag at converge time (do not store here)

# --------------------------------------------------------------------
# ACL / Cluster Bootstrap
# --------------------------------------------------------------------

default['nomad']['acl']['enabled']             = true
default['nomad']['acl']['bootstrap_this_node'] = false # Set true on exactly one server node
# Optional hardening: default token TTL for issued tokens (rendered only if set in template)
default['nomad']['acl']['token_ttl']           = '72h'

# --------------------------------------------------------------------
# Network / Firewall (optional consumers)
# --------------------------------------------------------------------

default['nomad']['allowed_cidrs'] = ['192.168.68.0/24'] # If you wire a firewall recipe to use this
