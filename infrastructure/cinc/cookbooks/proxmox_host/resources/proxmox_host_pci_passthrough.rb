# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_pci_passthrough
#
# Full PCI device passthrough enablement for proxmox hypervisors that
# hand a discrete GPU (or other PCI device) directly to a guest VM. Owns
# the vfio kernel modules in /etc/modules and /etc/modprobe.d/vfio.conf
# with the device IDs to bind at boot. The matching IOMMU kernel cmdline
# params are owned by proxmox_host_kernel_cmdline (gated on this
# pci_passthrough.enabled flag).
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_pci_passthrough

property :enabled,       [true, false], default: false
property :modules,       Array, default: %w(vfio vfio_iommu_type1 vfio_pci)
property :device_ids,    Array, default: []
property :modules_path,  String, default: '/etc/modules'
property :modprobe_path, String, default: '/etc/modprobe.d/vfio.conf'

default_action :configure

action :configure do
  return unless new_resource.enabled

  new_resource.modules.each do |m|
    execute "ensure module #{m} in /etc/modules" do
      command "echo #{m} >> #{new_resource.modules_path}"
      not_if  "grep -qxE '^#{Regexp.escape(m)}$' #{new_resource.modules_path}"
    end
  end

  unless new_resource.device_ids.empty?
    file new_resource.modprobe_path do
      owner   'root'
      group   'root'
      mode    '0644'
      content "options vfio-pci ids=#{new_resource.device_ids.join(',')}\n"
    end
  end
end
