# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: sysctl
#
# Lays a hypervisor sysctl drop-in via the shared munchbox_base_sysctl
# resource (reloads against its own file, so it works on hosts without a
# stock /etc/sysctl.conf). Currently lowers vm.swappiness from 60 so the
# host shrinks page cache before paging out guest memory.
# -------------------------------------------------------------------------------

munchbox_base_sysctl 'proxmox-host' do
  path     '/etc/sysctl.d/99-proxmox-host.conf'
  settings node[cookbook]['sysctl']
end
