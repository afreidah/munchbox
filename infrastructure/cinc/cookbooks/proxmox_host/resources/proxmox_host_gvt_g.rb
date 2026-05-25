# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_gvt_g
#
# Intel iGPU mediated device (GVT-g) enablement for proxmox hypervisors
# that share their iGPU across guest VMs. Owns the full
# GRUB_CMDLINE_LINUX_DEFAULT value (per-node attribute) + appends the
# vfio/kvmgt kernel modules to /etc/modules. Reboot is operator-gated
# (not auto-triggered; proxmox hosts run VMs).
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_gvt_g

property :enabled,       [true, false], default: false
property :cmdline_default, String, default: 'quiet intel_iommu=on i915.enable_gvt=1'
property :modules,       Array, default: %w(kvmgt vfio-iommu-type1 vfio-mdev)
property :grub_path,     String, default: '/etc/default/grub'
property :modules_path,  String, default: '/etc/modules'

default_action :configure

action :configure do
  return unless new_resource.enabled

  desired_line = %(GRUB_CMDLINE_LINUX_DEFAULT="#{new_resource.cmdline_default}")

  # --- lineinfile-style replacement of the single managed line. Only fires when the line differs (idempotent on no-op converge). ---
  execute 'update GRUB_CMDLINE_LINUX_DEFAULT (gvt_g)' do
    command "sed -i.bak -E 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|#{desired_line}|' #{new_resource.grub_path}"
    not_if  "grep -qxF '#{desired_line}' #{new_resource.grub_path}"
    notifies :run, 'execute[update-grub (gvt_g)]', :immediately
  end

  execute 'update-grub (gvt_g)' do
    command 'update-grub'
    action  :nothing
  end

  new_resource.modules.each do |m|
    execute "ensure module #{m} in /etc/modules" do
      command "echo #{m} >> #{new_resource.modules_path}"
      not_if  "grep -qxE '^#{Regexp.escape(m)}$' #{new_resource.modules_path}"
    end
  end
end
