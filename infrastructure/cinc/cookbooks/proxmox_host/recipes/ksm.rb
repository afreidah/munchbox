# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: ksm
# -------------------------------------------------------------------------------

proxmox_host_ksm 'ksm' do
  enabled node[cookbook]['ksm']['enabled']
end
