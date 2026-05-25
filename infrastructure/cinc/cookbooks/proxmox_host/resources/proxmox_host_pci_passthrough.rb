# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_pci_passthrough
#
# Full PCI device passthrough enablement for proxmox hypervisors that
# hand a discrete GPU (or other PCI device) directly to a guest VM.
# Owns the full GRUB_CMDLINE_LINUX_DEFAULT value, the vfio kernel
# modules in /etc/modules, and /etc/modprobe.d/vfio.conf with the
# device IDs to bind at boot. Reboot is operator-gated.
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_pci_passthrough

property :enabled,         [true, false], default: false
property :cmdline_default, String, default: 'quiet intel_iommu=on iommu=pt'
property :modules,         Array, default: %w(vfio vfio_iommu_type1 vfio_pci)
property :device_ids,      Array, default: []
property :grub_path,       String, default: '/etc/default/grub'
property :modules_path,    String, default: '/etc/modules'
property :modprobe_path,   String, default: '/etc/modprobe.d/vfio.conf'

default_action :configure

action :configure do
  return unless new_resource.enabled

  desired_line = %(GRUB_CMDLINE_LINUX_DEFAULT="#{new_resource.cmdline_default}")

  execute 'update GRUB_CMDLINE_LINUX_DEFAULT (pci_passthrough)' do
    command "sed -i.bak -E 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|#{desired_line}|' #{new_resource.grub_path}"
    not_if  "grep -qxF '#{desired_line}' #{new_resource.grub_path}"
    notifies :run, 'execute[update-grub (pci_passthrough)]', :immediately
  end

  execute 'update-grub (pci_passthrough)' do
    command 'update-grub'
    action  :nothing
  end

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
