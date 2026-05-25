# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Recipe:: minio_mount
#
# Wrapper -- mounts the OCI block volume tagged
# node[:oracle][:minio_mount][:label] at the configured mount point.
# Work lives in oracle_minio_mount.
# -------------------------------------------------------------------------------

mm = node[cookbook]['minio_mount']

oracle_minio_mount mm['mount_point'] do
  label         mm['label']
  fstype        mm['fstype']
  options       mm['options']
  legacy_device mm['legacy_device']
end
