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
default['consul']['version']        = '1.21.0'
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

# List of Consul server nodes for Raft quorum
default['consul']['servers'] = %w(
  192.168.1.225
  192.168.1.222
  192.168.1.98
)

default['consul']['server']['enable']           = true
default['consul']['server']['bootstrap_expect'] = node['consul']['servers'].length

# --------------------------------------------------------------------
# Consul Cluster Join / DNS
# --------------------------------------------------------------------

# retry_join typically equals the server list
default['consul']['retry_join'] = node['consul']['servers']

# Recursors used by Consul DNS (Pi-hole forwards .consul here; Consul forwards upstream lookups to these)
default['consul']['recursors'] = %w(
  1.1.1.1
  9.9.9.9
)

# --------------------------------------------------------------------
# Security: Gossip (Serf) & ACL tokens
# --------------------------------------------------------------------

# Gossip encryption key (generate with `consul keygen` and override per-env)
default['consul']['serf_key'] = 'REPLACE_WITH_consul_keygen'

# Agent/default tokens will be set post-bootstrap (leave nil in git)
default['consul']['acl']['tokens']['agent']   = nil
default['consul']['acl']['tokens']['default'] = nil
