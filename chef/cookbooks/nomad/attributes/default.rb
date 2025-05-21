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
default['nomad']['version']         = '1.7.1'
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
  # Shared data volume
  {
    'name' => 'shared_data',
    'path' => '/opt/nomad/shared-data',
    'read_only' => false
  },
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

default['nomad']['consul']['auto_agent'] = true
default['nomad']['consul']['auto_join']  = true
