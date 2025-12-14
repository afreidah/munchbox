# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Ceph Cookbook - Default Attributes
#
# Project: Munchbox / Author: Alex Freidah
#
# Default attributes for Ceph distributed storage cluster configuration.
# -------------------------------------------------------------------------------

# --- Ceph Version ---

default['ceph']['release'] = 'reef'

# --------------------------------------------------------------------
# Bootstrap Configuration
# --------------------------------------------------------------------

default['ceph']['bootstrap_node'] = 'cabot'
default['ceph']['mon_network']    = '192.168.68.0/24'

# --------------------------------------------------------------------
# Cluster Nodes
# --------------------------------------------------------------------

default['ceph']['nodes'] = [
  'cabot',
  'mccoy.munchbox',
  'goren',
  'stabler.munchbox'
]

# --------------------------------------------------------------------
# Installation Options
# --------------------------------------------------------------------

default['ceph']['skip_monitoring'] = true
default['ceph']['skip_dashboard']  = false

# --------------------------------------------------------------------
# OSD Configuration
# --------------------------------------------------------------------

default['ceph']['auto_discover_osds'] = false

# Directory-based OSD configuration
default['ceph']['osd']['use_directory'] = true
default['ceph']['osd']['directory']     = '/var/lib/ceph-storage'

# Per-node allocations (support both FQDN and short hostname)
default['ceph']['osd']['allocations'] = {
  'mccoy.munchbox'   => 70,
  'mccoy'            => 70,
  'stabler.munchbox' => 23,
  'stabler'          => 23,
  'goren.munchbox'   => 150,
  'goren'            => 150,
  'cabot.munchbox'   => 140,
  'cabot'            => 140
}

# Fallback size if node not in allocations hash
default['ceph']['osd']['size_gb'] = 50

# --------------------------------------------------------------------
# Storage Pool Configuration
# --------------------------------------------------------------------

default['ceph']['pool']['name']     = 'nomad-volumes'
default['ceph']['pool']['pg_num']   = 128
default['ceph']['pool']['size']     = 3
default['ceph']['pool']['min_size'] = 2

# --------------------------------------------------------------------
# Firewall Configuration
# --------------------------------------------------------------------

default['ceph']['allowed_cidrs'] = ['192.168.68.0/24']

# --------------------------------------------------------------------
# Prometheus Integration
# --------------------------------------------------------------------

default['ceph']['prometheus']['enabled'] = true
default['ceph']['prometheus']['port']    = 9283
