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

default['nomad']['version']    = '1.10.3'
default['nomad']['bin_path']   = '/usr/local/bin'
default['nomad']['user']       = 'root'
default['nomad']['group']      = 'root'
default['nomad']['config_dir'] = '/etc/nomad.d'
default['nomad']['data_dir']   = '/opt/nomad'
default['nomad']['bind_addr']  = node['ipaddress'] # Override on multihomed hosts
default['nomad']['datacenter'] = 'pi-dc'

default['nomad']['checksums'] = {
  '1.10.3' => {
    'amd64' => 'a161b8d59b42555d97d37f7a75c122831be485e89dfb97d16d6b60cfaec8d88b', # nomad_1.10.3_linux_amd64.zip
    'arm64' => '33d29315154035295a0f735622da4322ea500e49b5f85686139e76a5e89a7ce9', # nomad_1.10.3_linux_arm64.zip
  },
}

# --------------------------------------------------------------------
# Server Role
# --------------------------------------------------------------------

default['nomad']['server']['enabled']         = true
default['nomad']['server']['raft_multiplier'] = 2
default['nomad']['server']['retry_interval']  = '15s'
default['nomad']['server']['retry_max']       = 5

# Static peer list used for server_join.retry_join (host:4648 will be derived)
default['nomad']['server']['servers'] = %w(
  192.168.1.225
  192.168.1.222
  192.168.1.98
  192.168.1.115
)

# --------------------------------------------------------------------
# Client Role
# --------------------------------------------------------------------

default['nomad']['client']['enabled']    = true
default['nomad']['client']['node_class'] = ''
default['nomad']['client']['cni_path']   = '/opt/cni/bin'

# Host volumes exposed to jobs (paths are created with permissive mode by default)
default['nomad']['client']['host_volumes'] = [
]

# --------------------------------------------------------------------
# Docker Task Driver
# --------------------------------------------------------------------

default['nomad']['docker']['allow_privileged']   = true
default['nomad']['docker']['volumes']['enabled'] = true
default['nomad']['docker']['caps']               = %w(NET_ADMIN)

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
default['nomad']['vault']['address'] = 'http://192.168.1.222:8200'
# Token is sourced from encrypted data bag at converge time (do not store here)

# --------------------------------------------------------------------
# ACL / Cluster Bootstrap
# --------------------------------------------------------------------

default['nomad']['acl']['enabled']             = true
default['nomad']['acl']['bootstrap_this_node'] = false # Set true on exactly one server node

# --------------------------------------------------------------------
# Network / Firewall (optional consumers)
# --------------------------------------------------------------------

default['nomad']['allowed_cidrs'] = ['192.168.1.0/24'] # If you wire a firewall recipe to use this
