# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: gvt_g
# -------------------------------------------------------------------------------

proxmox_host_gvt_g 'gvt_g' do
  enabled node[cookbook]['gvt_g']['enabled']
  modules node[cookbook]['gvt_g']['modules']
end
