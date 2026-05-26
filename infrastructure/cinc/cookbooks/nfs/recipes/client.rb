# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nfs
# Recipe:: client
#
# Installs nfs-common and materializes every mount declared in
# node[cookbook][:client][:mounts] via the nfs_mount custom resource.
# -------------------------------------------------------------------------------

client = node[cookbook]['client']

# --- ensure the apt package list is fresh so chef's apt_package doesn't pin a
#     stale version (greenfield / kitchen guests don't otherwise apt-update).
apt_update 'nfs-client' do
  action :periodic
  frequency 86_400
end

apt_package client['package'] do
  action :install
end

(client['mounts'] + (client['extra_mounts'] || [])).each do |m|
  nfs_mount m['mount_point'] do
    device  m['device']
    fstype  m['fstype']  if m['fstype']
    options m['options'] if m['options']
  end
end
