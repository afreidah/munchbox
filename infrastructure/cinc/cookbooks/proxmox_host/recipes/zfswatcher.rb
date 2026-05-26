# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Recipe:: zfswatcher
#
# Build the binary from source (idempotent, only fires on ref drift),
# then configure + start the daemon. Both halves are no-ops when
# `zfswatcher.enabled` is false (the build only runs when enabled, the
# daemon-side resource handles its own disabled path).
# -------------------------------------------------------------------------------

build = node[cookbook]['zfswatcher_build']
vp    = node[cookbook]['vault_paths']['zfswatcher_proxy_password']

# --- Build first so the binary exists by the time the daemon resource tries to start it ---
if node[cookbook]['zfswatcher']['enabled']
  proxmox_host_zfswatcher_build 'zfswatcher' do
    repo_url    build['repo_url']
    ref         build['ref']
    install_dir build['install_dir']
    src_dir     build['src_dir']
    bin_path    node[cookbook]['zfswatcher']['bin_path']
    build_cmd   build['build_cmd']
  end
end

proxmox_host_zfswatcher 'zfswatcher' do
  enabled              node[cookbook]['zfswatcher']['enabled']
  bin_path             node[cookbook]['zfswatcher']['bin_path']
  config_path          node[cookbook]['zfswatcher']['config_path']
  log_dir              node[cookbook]['zfswatcher']['log_dir']
  bind                 node[cookbook]['zfswatcher']['bind']
  # --- attribute override wins (kitchen / break-glass); otherwise lazy vault_fetch at converge time ---
  proxy_password_hash(lazy { node[cookbook]['zfswatcher']['proxy_password_hash'] || vault_fetch(vp['path'], vp['field']) })
end
