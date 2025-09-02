# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: pi_bootstrap
# Recipe:: gdrive_mount
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Mounts a remote Google Drive (via SSHFS) from 'mccoy' to /mnt/gdrive.
# Ensures the mount point exists and persists the mount in /etc/fstab.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Ensure Mount Point Exists
# --------------------------------------------------------------------

directory '/mnt/gdrive' do
  owner 'afreidah'
  group 'afreidah'
  mode '0755'
  action :create
end

# --------------------------------------------------------------------
# Mount Remote GDrive via SSHFS and Persist in fstab
# --------------------------------------------------------------------

mount '/mnt/gdrive' do
  device 'mccoy:/mnt/gdrive'
  fstype 'fuse.sshfs'
  options '_netdev,users,idmap=user,IdentityFile=/root/.ssh/id_rsa,allow_other,default_permissions,reconnect'
  action [:mount, :enable]
end
