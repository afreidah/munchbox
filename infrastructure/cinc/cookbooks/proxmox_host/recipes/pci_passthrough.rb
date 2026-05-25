# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: pci_passthrough
# -------------------------------------------------------------------------------

proxmox_host_pci_passthrough 'pci_passthrough' do
  enabled    node[cookbook]['pci_passthrough']['enabled']
  modules    node[cookbook]['pci_passthrough']['modules']
  device_ids node[cookbook]['pci_passthrough']['device_ids']
end
