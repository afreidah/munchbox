# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_kernel_cmdline
#
# Single owner of GRUB_CMDLINE_LINUX_DEFAULT. Composes the line from a
# base plus the IOMMU params each GPU mode needs (gvt_g / pci_passthrough)
# plus optional mitigations=off, so cmdline policy lives in one place
# instead of being fought over by separate recipes. Runs update-grub on
# change; the reboot to pick it up is operator-gated.
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_kernel_cmdline

property :base,            Array, default: ['quiet']
property :gvt_g,           [true, false], default: false
property :pci_passthrough, [true, false], default: false
property :mitigations_off, [true, false], default: false
property :grub_path,       String, default: '/etc/default/grub'

default_action :configure

action :configure do
  params = new_resource.base.dup
  params.push('intel_iommu=on', 'i915.enable_gvt=1') if new_resource.gvt_g
  params.push('intel_iommu=on', 'iommu=pt') if new_resource.pci_passthrough
  params << 'mitigations=off' if new_resource.mitigations_off

  desired_line = %(GRUB_CMDLINE_LINUX_DEFAULT="#{params.uniq.join(' ')}")

  execute 'update GRUB_CMDLINE_LINUX_DEFAULT' do
    command  "sed -i.bak -E 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|#{desired_line}|' #{new_resource.grub_path}"
    not_if   "grep -qxF '#{desired_line}' #{new_resource.grub_path}"
    notifies :run, 'execute[update-grub]', :immediately
  end

  execute 'update-grub' do
    command 'update-grub'
    action  :nothing
  end
end
