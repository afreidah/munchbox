# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_ksm
#
# Ensures Proxmox's ksm-control-daemon is installed and its ksmtuned
# service runs, so the kernel dedupes identical guest memory pages on
# demand (it self-activates only under memory pressure, so it is safe
# fleet-wide). NOTE: this is PVE's ksm-control-daemon, NOT Debian's
# ksmtuned package -- the two both own /etc/ksmtuned.conf and conflict.
# enabled=false stops + disables the service without removing the package.
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_ksm

property :enabled, [true, false], default: true

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  package 'ksm-control-daemon' do
    action(new_resource.enabled ? :install : :nothing)
  end

  service 'ksmtuned' do
    action(new_resource.enabled ? %i(enable start) : %i(stop disable))
  end
end
