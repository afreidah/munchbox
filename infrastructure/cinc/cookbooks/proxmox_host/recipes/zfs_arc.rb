# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: zfs_arc
# -------------------------------------------------------------------------------

proxmox_host_zfs_arc 'zfs_arc' do
  max_bytes node[cookbook]['zfs_arc']['max_bytes']
end
