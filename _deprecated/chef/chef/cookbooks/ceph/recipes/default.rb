# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Ceph Cookbook - Default Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Main entry point for Ceph installation. Installs on all nodes and bootstraps
# on designated node.
# -------------------------------------------------------------------------------

# --- Install Ceph Prerequisites & Packages ---

include_recipe 'ceph::install'

# --------------------------------------------------------------------
# Configure Firewall Rules
# --------------------------------------------------------------------

# include_recipe 'ceph::firewall'

# --------------------------------------------------------------------
# Create OSD Directory (All Nodes)
# --------------------------------------------------------------------

include_recipe 'ceph::osd'

# --------------------------------------------------------------------
# Bootstrap Cluster (Bootstrap Node Only)
# --------------------------------------------------------------------

bootstrap_node = node['ceph']['bootstrap_node']
current_node   = node['hostname']

if current_node == bootstrap_node
  include_recipe 'ceph::bootstrap'
  include_recipe 'ceph::deploy_osds'  # Add this line
else
  log 'ceph-node' do
    message "Node #{current_node} will be added to cluster by bootstrap node #{bootstrap_node}"
    level :info
  end
end
