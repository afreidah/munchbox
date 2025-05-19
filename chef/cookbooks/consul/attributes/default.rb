# frozen_string_literal: true
#
# Cookbook:: consul
# Attributes:: default
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Default attributes for Consul installation and configuration.
#

# =========================
# Consul Installation
# =========================

default['consul']['version']        = '1.21.0'
default['consul']['install_method'] = 'binary'           # Options: 'binary', 'package'
default['consul']['install_dir']    = '/usr/local/bin'

# =========================
# Consul User & Group
# =========================

default['consul']['user']  = 'root'
default['consul']['group'] = 'root'

# =========================
# Consul Directories
# =========================

default['consul']['config_dir'] = '/etc/consul.d'
default['consul']['data_dir']   = '/opt/consul'

# =========================
# Consul Network
# =========================

default['consul']['bind_addr'] = node['ipaddress']

# =========================
# Consul Server Configuration
# =========================

# List of Consul server nodes for Raft quorum
default['consul']['servers'] = %w(
  192.168.1.225
  192.168.1.222
  192.168.1.98
)

default['consul']['server']['enable'] = true
