# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Resource:: oracle_minio_mount
#
# Persistently mounts an OCI block volume (looked up by LABEL) at the
# given mount point via a UUID-based fstab entry. Sweeps the legacy
# /dev/sdb entry from the pre-UUID era.
#
# No-op (warns) when no labeled volume is found, so the resource is safe
# to declare on every oracle node regardless of whether the block volume
# is attached yet.
# -------------------------------------------------------------------------------

unified_mode true

provides :oracle_minio_mount

property :mount_point,   String, name_property: true
property :label,         String, required: true
property :fstype,        String, default: 'ext4'
property :options,       String, default: 'defaults,nofail,_netdev'
property :legacy_device, String, default: '/dev/sdb'

default_action :mount

action :mount do
  directory new_resource.mount_point do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  blkid = shell_out('blkid', '-t', "LABEL=#{new_resource.label}", '-o', 'value', '-s', 'UUID')
  uuid  = blkid.stdout.chomp

  if uuid.empty?
    Chef::Log.warn("oracle_minio_mount[#{new_resource.name}]: no volume with LABEL=#{new_resource.label} found; skipping mount")
    return
  end

  legacy = new_resource.legacy_device
  mp     = new_resource.mount_point

  mount "remove legacy #{legacy} entry at #{mp}" do
    mount_point mp
    device      legacy
    action      :disable
    only_if     { ::File.read('/etc/fstab').match?(/^#{Regexp.escape(legacy)}\s+#{Regexp.escape(mp)}\s/) }
  end

  mount new_resource.mount_point do
    device      uuid
    device_type :uuid
    fstype      new_resource.fstype
    options     new_resource.options
    action      %i(mount enable)
  end
end
