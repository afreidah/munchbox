# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  attributes/default.rb — Attribute defaults for OpenBao installation
#
#  Defines default attributes used by the install recipe for OpenBao.
# ------------------------------------------------------------------------------

# --- General Installation Attributes ---
default[cookbook_name]['openbao']['version']  = '0.2.1'
default[cookbook_name]['user']                = 'openbao'
default[cookbook_name]['group']               = 'openbao'
default[cookbook_name]['svc_name']            = 'openbao'
default[cookbook_name]['region']              = 'us-west-2'
default[cookbook_name]['hostname']            = 'openbao.example.com'
default[cookbook_name]['config_path']         = '/etc/openbao/openbao.hcl'
default[cookbook_name]['firewall_stamp_file'] = '/etc/openbao/firewall.stamp'

# --- Ports to open in firewall ---
default[cookbook_name]['ufw_ports'] = %w(
  8200
  8201
)

# --- Default Packages to install ---
default[cookbook_name]['install_packages'] = %w(
  unzip
  curl
  golang
)

# --- Default Directories to create ---
default[cookbook_name]['directories'] = %w(
  /etc/openbao
  /opt/openbao/tls
  /opt/openbao/data
)

# --- Storage Cluster Attributes ---
default[cookbook_name]['storage']['type'] = 'raft'
default[cookbook_name]['storage']['path'] = '/opt/openbao/data'

# --- SSL Configuration ---
default[cookbook_name]['ssl']['data_bag']         = 'infra_certs'
default[cookbook_name]['ssl']['data_bag_item']    = 'ssl'
default[cookbook_name]['ssl']['data_bag_section'] = 'openbao'
default[cookbook_name]['ssl']['target_path']      = '/opt/openbao/tls'

# --------------------------------------------------------------------
# Firewall Rules
# --------------------------------------------------------------------

default[cookbook_name]['openbao_firewall_rules'] = [
  { name: '8200',  port: 8200, protocol: :tcp },
  { name: '8201',  port: 8201, protocol: :tcp },
]
