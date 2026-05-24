# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Recipe:: configure
#
# Iterates over `node[cookbook]['interfaces']` and declares a
# `wireguard_interface` resource for each. Each interface renders its own
# /etc/wireguard/<iface>.conf and manages its own wg-quick@<iface>.service.
# -------------------------------------------------------------------------------

node[cookbook]['interfaces'].to_hash.each do |iface_name, iface_cfg|
  cfg = iface_cfg.to_hash

  wireguard_interface iface_name do
    address              cfg.fetch('address')
    listen_port          cfg['listen_port']
    mtu                  cfg['mtu']
    private_key          cfg['private_key']
    vault_path           cfg['vault_path']
    vault_field          cfg.fetch('vault_field', 'private_key')
    post_up              Array(cfg['post_up'])
    post_down            Array(cfg['post_down'])
    peers                Array(cfg['peers']).map(&:to_hash)
  end
end
