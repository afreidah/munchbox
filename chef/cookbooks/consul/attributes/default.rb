# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: consul
# Attributes:: default
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Default attributes for Consul installation and configuration.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Consul Installation
# --------------------------------------------------------------------

default['consul']['install_method'] = 'binary'
default['consul']['version']        = '1.21.3'
default['consul']['install_dir']    = '/usr/local/bin'

# --------------------------------------------------------------------
# Consul User & Group
# --------------------------------------------------------------------

default['consul']['user']  = 'root'
default['consul']['group'] = 'root'

# --------------------------------------------------------------------
# Consul Directories
# --------------------------------------------------------------------

default['consul']['data_dir']   = '/opt/consul'
default['consul']['config_dir'] = '/etc/consul.d'

# --------------------------------------------------------------------
# Serf Key from Data Bag
# --------------------------------------------------------------------

default['consul']['databag_name'] = 'consul'
default['consul']['databag_item'] = 'gossip'

# --------------------------------------------------------------------
# Consul Identity
# --------------------------------------------------------------------

default['consul']['datacenter'] = 'dc1'
default['consul']['node_name']  = node['hostname']

# --------------------------------------------------------------------
# Consul Network
# --------------------------------------------------------------------

default['consul']['bind_addr']      = ENV['CONSUL_BIND_ADDR'] || node['ipaddress'] || '0.0.0.0' # LAN bind
default['consul']['advertise_addr'] = ENV['CONSUL_ADVERTISE_ADDR'] || node['ipaddress'] || `hostname -I`.split.first

# --------------------------------------------------------------------
# Consul Logging / UI
# --------------------------------------------------------------------

default['consul']['log_level'] = 'INFO'
default['consul']['ui']        = true # UI enabled; HTTP kept on 127.0.0.1 (proxied via Traefik)

# --------------------------------------------------------------------
# Consul Server Configuration
# --------------------------------------------------------------------

default['consul']['server']['enable']           = true
default['consul']['server']['bootstrap_expect'] = 3

# --------------------------------------------------------------------
# TLS configuration
# --------------------------------------------------------------------

default['consul']['tls']['ca_from_databag'] = true
default['consul']['tls']['bootstrap_ca']    = false

# --------------------------------------------------------------------
# Consul Cluster Join / DNS
# --------------------------------------------------------------------

# --- retry_join typically equals the server list ---
default['consul']['retry_join'] = [
  '192.168.68.60',
  '192.168.68.61',
  '192.168.68.63'
]

# --- Recursors used by Consul DNS (Pi-hole forwards .consul here; Consul forwards upstream lookups to these) ---
default['consul']['recursors'] = %w(
  1.1.1.1
  9.9.9.9
)

# --------------------------------------------------------------------
# Security: Gossip (Serf) & ACL tokens
# --------------------------------------------------------------------

# --- Agent/default tokens will be set post-bootstrap (leave nil in git) ---
default['consul']['acl']['enabled'] = true
default['consul']['acl']['tokens']['agent']   = nil
default['consul']['acl']['tokens']['default'] = nil

# --------------------------------------------------------------------
# Firewall Rules
# --------------------------------------------------------------------

default['consul']['consul_firewall_rules'] = [
  { name: 'consul-raft',          port: 8300, protocol: :tcp },
  { name: 'consul-serf-lan-tcp',  port: 8301, protocol: :tcp },
  { name: 'consul-serf-lan-udp',  port: 8301, protocol: :udp },
  { name: 'consul-serf-wan-tcp',  port: 8302, protocol: :tcp },
  { name: 'consul-serf-wan-udp',  port: 8302, protocol: :udp },
  { name: 'consul-http',          port: 8500, protocol: :tcp },
  { name: 'consul-dns-tcp',       port: 8600, protocol: :tcp },
  { name: 'consul-dns-udp',       port: 8600, protocol: :udp },
  { name: 'consul-grpc-udp',      port: 8502, protocol: :udp },
  { name: 'consul-grpc-udp',      port: 8502, protocol: :udp },
  { name: 'consul-grpc_tls-udp',  port: 8503, protocol: :udp },
  { name: 'consul-grpc_tls-udp',  port: 8503, protocol: :udp },
]
