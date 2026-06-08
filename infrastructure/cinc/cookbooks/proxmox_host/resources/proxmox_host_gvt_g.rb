# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_gvt_g
#
# Intel iGPU mediated device (GVT-g) enablement for proxmox hypervisors
# that share their iGPU across guest VMs. Appends the vfio/kvmgt kernel
# modules to /etc/modules. The matching IOMMU kernel cmdline params are
# owned by proxmox_host_kernel_cmdline (gated on this gvt_g.enabled flag).
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_gvt_g

property :enabled, [true, false], default: false
property :modules,      Array, default: %w(kvmgt vfio-iommu-type1 vfio-mdev)
property :modules_path, String, default: '/etc/modules'

default_action :configure

action :configure do
  return unless new_resource.enabled

  new_resource.modules.each do |m|
    execute "ensure module #{m} in /etc/modules" do
      command "echo #{m} >> #{new_resource.modules_path}"
      not_if  "grep -qxE '^#{Regexp.escape(m)}$' #{new_resource.modules_path}"
    end
  end
end
