# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nfs
# Resource:: nfs_mount
#
# Ensures an NFS export is mounted and persisted in fstab. Creates the
# mount point if missing. Generic across NFS versions: caller picks
# fstype (nfs / nfs4) and mount options.
#
# Properties:
#   mount_point - Local directory (name property).
#   device      - NFS source, "server:/export". Required.
#   fstype      - Default 'nfs'.
#   options     - Comma-separated mount opts. Default 'defaults,_netdev'
#                 (_netdev so systemd doesn't block boot on a stale server).
#   owner/group/mode - Mount-point dir attrs; defaults to root:root 0755.
# -------------------------------------------------------------------------------

unified_mode true

provides :nfs_mount

property :mount_point, String, name_property: true
property :device,      String, required: true
property :fstype,      String, default: 'nfs'
property :options,     String, default: 'defaults,_netdev'
property :owner,       String, default: 'root'
property :group,       String, default: 'root'
property :mode,        String, default: '0755'

default_action :create

# -------------------------------------------------------------------------------
# Action :create  --  Ensure dir exists, fstab entry present, mount active
# -------------------------------------------------------------------------------

action :create do
  directory new_resource.mount_point do
    owner     new_resource.owner
    group     new_resource.group
    mode      new_resource.mode
    recursive true
    not_if { ::File.directory?(new_resource.mount_point) }
  end

  mount new_resource.mount_point do
    device  new_resource.device
    fstype  new_resource.fstype
    options new_resource.options
    action  [:mount, :enable]
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Unmount + drop from fstab. Doesn't delete the dir.
# -------------------------------------------------------------------------------

action :remove do
  mount new_resource.mount_point do
    device new_resource.device
    fstype new_resource.fstype
    action [:umount, :disable]
  end
end
