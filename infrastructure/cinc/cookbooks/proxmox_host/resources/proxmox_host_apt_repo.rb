# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_apt_repo
#
# Owns the PVE no-subscription apt source authoritatively so its codename
# tracks the host OS. The release codename is read from /etc/os-release
# (node['os_release']) rather than lsb, which is absent on greenfield
# nodes. Fixes hosts whose source drifted (e.g. left at `bookworm` after a
# trixie upgrade) and is a no-op where it already matches.
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_apt_repo

property :manage,   [true, false], default: true
property :path,     String, default: '/etc/apt/sources.list.d/pve-no-subscription.list'
property :codename, [String, nil], default: lazy { (node['os_release'] || {})['version_codename'] }

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  return unless new_resource.manage

  apt_update 'pve-no-subscription-changed' do
    action :nothing
  end

  file new_resource.path do
    owner    'root'
    group    'root'
    mode     '0644'
    content  "deb http://download.proxmox.com/debian/pve #{new_resource.codename} pve-no-subscription\n"
    notifies :update, 'apt_update[pve-no-subscription-changed]', :delayed
  end
end
