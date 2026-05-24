# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Recipe:: minio_mount
#
# Ensures the OCI block volume tagged `minio-data` is persistently
# mounted at /mnt/minio-data via a UUID-based fstab entry. Without this,
# a kernel-upgrade reboot leaves the volume detached and MinIO comes up
# against an empty root-fs stub (the bucket on oracle-arm-2 went missing
# this way in May 2026).
#
# UUID is resolved at converge time via blkid; if no labeled volume is
# found we skip with a warning rather than raise -- this recipe should
# be a no-op on nodes where the volume hasn't been attached yet.
# -------------------------------------------------------------------------------

mm = node[cookbook]['minio_mount']

directory mm['mount_point'] do
  owner 'root'
  group 'root'
  mode  '0755'
end

# --- Look up the UUID by label at converge time; chef's mount resource needs the bare UUID for device_type :uuid. ---
blkid = shell_out('blkid', '-t', "LABEL=#{mm['label']}", '-o', 'value', '-s', 'UUID')
uuid  = blkid.stdout.chomp

if uuid.empty?
  Chef::Log.warn("oracle::minio_mount: no volume with LABEL=#{mm['label']} found; skipping mount")
  return
end

# --- Drop the legacy /dev/sdb fstab entry if it's still there (superseded by the UUID entry). ---
mount "remove legacy #{mm['legacy_device']} entry at #{mm['mount_point']}" do
  mount_point mm['mount_point']
  device      mm['legacy_device']
  action      :disable
  only_if     { ::File.read('/etc/fstab').match?(/^#{Regexp.escape(mm['legacy_device'])}\s+#{Regexp.escape(mm['mount_point'])}\s/) }
end

mount mm['mount_point'] do
  device      uuid
  device_type :uuid
  fstype      mm['fstype']
  options     mm['options']
  action      %i(mount enable)
end
