# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Ceph Cookbook - Deploy OSDs Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates loopback devices from OSD files and deploys OSDs on bootstrap node.
# -------------------------------------------------------------------------------

# --- Only Run on Bootstrap Node ---

bootstrap_node = node['ceph']['bootstrap_node']
current_node   = node['hostname']

return unless current_node == bootstrap_node

# --------------------------------------------------------------------
# Wait for Cluster to be Ready
# --------------------------------------------------------------------

execute 'wait-for-ceph-before-osd' do
  command     'ceph status'
  retries     10
  retry_delay 5
end

# --------------------------------------------------------------------
# Get All Cluster Nodes
# --------------------------------------------------------------------

cluster_nodes = Array(node['ceph']['nodes'])

# --------------------------------------------------------------------
# Create Loopback Devices and Deploy OSDs
# --------------------------------------------------------------------

cluster_nodes.each do |hostname|
  # Create loopback device on remote node
  execute "create-loopback-#{hostname}" do
    command <<-EOH
      ssh root@#{hostname} '
        if ! losetup -l | grep -q /var/lib/ceph-storage/osd-block; then
          losetup -f /var/lib/ceph-storage/osd-block
        fi
      '
    EOH
    only_if "ssh root@#{hostname} 'test -f /var/lib/ceph-storage/osd-block'"
  end

  # Get the loop device path
  ruby_block "deploy-osd-#{hostname}" do
    block do
      require 'open3'
      
      # Get loop device path
      stdout, _stderr, status = Open3.capture3(
        "ssh root@#{hostname} \"losetup -l | grep /var/lib/ceph-storage/osd-block | awk '{print \\$1}'\""
      )
      
      if status.success? && !stdout.strip.empty?
        loop_device = stdout.strip
        Chef::Log.info("Deploying OSD on #{hostname} using #{loop_device}")
        
        # Deploy OSD using the loop device
        system("ceph orch daemon add osd #{hostname}:#{loop_device}")
        sleep 5
      else
        Chef::Log.warn("Could not find loop device on #{hostname}")
      end
    end
    action :run
  end
end

# --------------------------------------------------------------------
# Wait for OSDs to be Created
# --------------------------------------------------------------------

execute 'wait-for-osds-deployed' do
  command     'sleep 10 && ceph osd tree'
  retries     10
  retry_delay 10
  only_if     'ceph status'
end

# --------------------------------------------------------------------
# OSD Deployment Complete
# --------------------------------------------------------------------

log 'ceph-osds-deployed' do
  message 'Ceph OSDs deployed successfully on all nodes'
  level   :info
end
