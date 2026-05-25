# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: zfswatcher
# -------------------------------------------------------------------------------

vp = node[cookbook]['vault_paths']['zfswatcher_proxy_password']

proxmox_host_zfswatcher 'zfswatcher' do
  enabled              node[cookbook]['zfswatcher']['enabled']
  bin_path             node[cookbook]['zfswatcher']['bin_path']
  config_path          node[cookbook]['zfswatcher']['config_path']
  log_dir              node[cookbook]['zfswatcher']['log_dir']
  bind                 node[cookbook]['zfswatcher']['bind']
  proxy_password_hash(lazy { vault_fetch(vp['path'], vp['field']) })
end
