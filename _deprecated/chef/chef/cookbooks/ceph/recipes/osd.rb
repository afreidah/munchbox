# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Ceph Cookbook - OSD Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates directory-based OSDs for Ceph storage with per-node size allocations.
# -------------------------------------------------------------------------------

# --- Inputs / Defaults ---

use_directory = node.dig('ceph', 'osd', 'use_directory') ? true : false
osd_directory = node['ceph']['osd']['directory']
current_node  = node['hostname']

# --------------------------------------------------------------------
# Skip if Not Using Directory-Based OSDs
# --------------------------------------------------------------------

return unless use_directory

# --------------------------------------------------------------------
# Determine OSD Size for This Node
# --------------------------------------------------------------------

allocations = node['ceph']['osd']['allocations']
osd_size_gb = if allocations && allocations[current_node]
                allocations[current_node]
              else
                node['ceph']['osd']['size_gb']
              end

# --------------------------------------------------------------------
# Create OSD Directory
# --------------------------------------------------------------------

directory osd_directory do
  owner 'root'
  group 'root'
  mode  '0755'
  action :create
end

# --------------------------------------------------------------------
# Create Size Limit File
# --------------------------------------------------------------------

execute 'create-osd-size-limit' do
  command <<-EOH
    if [ ! -f #{osd_directory}/osd-block ]; then
      fallocate -l #{osd_size_gb}G #{osd_directory}/osd-block
    fi
  EOH
  not_if { ::File.exist?("#{osd_directory}/osd-block") }
end

# --------------------------------------------------------------------
# Set Appropriate Permissions
# --------------------------------------------------------------------

execute 'set-ceph-ownership' do
  command "chown -R 167:167 #{osd_directory}"
  only_if { ::Dir.exist?(osd_directory) }
end

# --------------------------------------------------------------------
# Log OSD Directory Setup
# --------------------------------------------------------------------

log 'ceph-osd-directory-ready' do
  message "Ceph OSD directory #{osd_directory} ready with #{osd_size_gb}GB limit on #{current_node}"
  level   :info
end
