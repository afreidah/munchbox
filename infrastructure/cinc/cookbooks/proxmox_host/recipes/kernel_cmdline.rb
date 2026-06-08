# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: kernel_cmdline
# -------------------------------------------------------------------------------

proxmox_host_kernel_cmdline 'grub' do
  base            node[cookbook]['kernel_cmdline']['base']
  gvt_g           node[cookbook]['gvt_g']['enabled']
  pci_passthrough node[cookbook]['pci_passthrough']['enabled']
  mitigations_off node[cookbook]['kernel_cmdline']['mitigations_off']
end
