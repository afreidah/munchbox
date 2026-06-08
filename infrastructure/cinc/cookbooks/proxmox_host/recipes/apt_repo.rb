# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: apt_repo
# -------------------------------------------------------------------------------

proxmox_host_apt_repo 'pve-no-subscription' do
  manage node[cookbook]['apt_repo']['manage']
end
