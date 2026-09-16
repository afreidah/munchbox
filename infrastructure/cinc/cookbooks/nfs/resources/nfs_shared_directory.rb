# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nfs
# Resource:: nfs_shared_directory
#
# Asserts a directory on an NFS share, as opposed to the mount point itself.
# Creation is guarded on the share being mounted: against a server that is down
# the create would land on the underlying filesystem, and the mount would then
# hide it, leaving a directory that exists, cannot be seen, and reappears empty
# whenever the mount drops.
#
# Every node mounting a share may converge the same directory. That is harmless:
# the first one creates it and the rest confirm it.
#
# Properties:
#   path        - Directory to assert (name property). Must sit under mount_point.
#   mount_point - Mount the directory lives on; creation is skipped unless this
#                 is mounted. Required.
#   owner/group/mode - Directory attrs; defaults to root:root 0755.
# -------------------------------------------------------------------------------

unified_mode true

provides :nfs_shared_directory

property :path,        String, name_property: true
property :mount_point, String, required: true
property :owner,       String, default: 'root'
property :group,       String, default: 'root'
property :mode,        String, default: '0755'

default_action :create

# -------------------------------------------------------------------------------
# Action :create  --  Assert the directory, but only once its share is mounted
# -------------------------------------------------------------------------------

action :create do
  unless new_resource.path.start_with?("#{new_resource.mount_point}/")
    raise Chef::Exceptions::ValidationFailed,
          "nfs_shared_directory #{new_resource.path} is not under #{new_resource.mount_point}"
  end

  directory new_resource.path do
    owner     new_resource.owner
    group     new_resource.group
    mode      new_resource.mode
    recursive true
    only_if   "mountpoint -q #{new_resource.mount_point}"
  end
end
