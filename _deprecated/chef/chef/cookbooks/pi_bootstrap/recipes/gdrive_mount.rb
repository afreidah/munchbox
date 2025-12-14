# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Pi Bootstrap Cookbook - GDrive Mount Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Mounts a remote Google Drive (via SSHFS) from 'mccoy' to /mnt/gdrive.
# -------------------------------------------------------------------------------

package 'sshfs' do
  action :install
end

# --- Ensure Mount Point Exists ---

directory '/mnt/gdrive' do
  owner 'afreidah'
  group 'afreidah'
  mode '0755'
  action :create
end

# --- Mount Remote GDrive via SSHFS and Persist in fstab ---

mount '/mnt/gdrive' do
  device 'mccoy:/mnt/gdrive'
  fstype 'fuse.sshfs'
  options '_netdev,users,idmap=user,IdentityFile=/root/.ssh/id_rsa,allow_other,default_permissions,reconnect'
  action [:mount, :enable]
end
