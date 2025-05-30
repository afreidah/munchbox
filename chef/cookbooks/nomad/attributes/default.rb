# frozen_string_literal: true
#
# Cookbook:: nomad
# Attributes:: default
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#

# =========================
# Nomad General Attributes
# =========================

default['nomad']['datacenter']      = 'pi-dc'
default['nomad']['version']         = '1.5.3'
default['nomad']['install_method']  = 'binary'
default['nomad']['user']            = 'root'
default['nomad']['group']           = 'root'
default['nomad']['config_dir']      = '/etc/nomad.d/'
default['nomad']['data_dir']        = '/opt/nomad/'
default['nomad']['bind_addr']       = node['ipaddress']
default['nomad']['bin_path']        = '/usr/local/bin'

# =========================
# Client Configuration
# =========================

default['nomad']['client']['enabled']      = true
default['nomad']['client']['node_class']   = ''
default['nomad']['client']['cni_path']     = '/opt/cni/bin'
default['nomad']['client']['host_volumes'] = [
  # Pi-hole config volume
  {
    'name' => 'pihole-config',
    'path' => '/opt/nomad/data/pihole/etc-pihole',
    'read_only' => false
  },
  # Pi-hole dnsmasq volume
  {
    'name' => 'pihole-dnsmasq',
    'path' => '/opt/nomad/data/pihole/dnsmasq.d',
    'read_only' => false
  },
  # Pi-hole unbound volume
  {
    'name' => 'unbound-data',
    'path' => '/opt/nomad/data/unbound',
    'read_only' => false
  }
  # grafana volume
  {
    'name' => 'grafana-data',
    'path' => '/opt/nomad/data/grafana/',
    'read_only' => false
  }
  # vault volume
  {
    'name' => 'vault-data',
    'path' => '/opt/nomad/data/vault/',
    'read_only' => false
  }
  # registry volume
  {
    'name' => 'registry-data',
    'path' => '/opt/nomad/data/registry/',
    'read_only' => false
  }
  # registry-ui volume
  {
    'name' => 'registry-ui-data',
    'path' => '/opt/nomad/data/registry-ui/',
    'read_only' => false
  }
]

# =========================
# Server Configuration
# =========================

default['nomad']['server']['enabled']          = true
default['nomad']['server']['raft_multiplier']  = 2
default['nomad']['server']['retry_interval']   = '15s'
default['nomad']['server']['retry_max']        = 5
default['nomad']['server']['servers'] = %w(
  192.168.1.225
  192.168.1.222
  192.168.1.98
  192.168.1.115
)

# =========================
# Docker Configuration
# =========================

default['nomad']['docker']['allow_privileged'] = true
default['nomad']['docker']['volumes']['enabled'] = true
default['nomad']['docker']['caps'] = %w(
  NET_ADMIN
)

# =========================
# Telemetry Configuration
# =========================

default['nomad']['telemetry']['enabled']                       = true
default['nomad']['telemetry']['collection_interval']           = '1s'
default['nomad']['telemetry']['disable_hostname']              = true
default['nomad']['telemetry']['prometheus_metrics']            = true
default['nomad']['telemetry']['publish_allocation_metrics']    = true
default['nomad']['telemetry']['publish_node_metrics']          = true

# =========================
# Consul Configuration
# =========================

default['nomad']['consul']['auto_advertise'] = true
default['nomad']['consul']['auto_join']  = true

# =========================
# CNI Configuration
# =========================
default['nomad']['cni']['version'] = 'v1.6.2'
default['nomad']['cni']['path'] = '/opt/cni/bin'
default['nomad']['cni']['url'] = "https://github.com/containernetworking/plugins/releases/download"

# =========================
# Vault Configuration
# =========================
default['nomad']['vault']['enabled'] = true
default['nomad']['vault']['address'] = 'http://192.168.1.222:8200'

