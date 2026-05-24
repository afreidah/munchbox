# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Resource:: wireguard_interface
#
# Renders /etc/wireguard/<name>.conf for a single interface and enables +
# starts the matching wg-quick@<name>.service. Same resource handles both
# server-side (ListenPort, no Endpoint on peers) and client-side
# (Endpoint + PersistentKeepalive on peers) shapes via optional
# properties.
#
# Key material is the cookbook's main responsibility-and-pain-point. Two
# ways to provide it:
#   1. Plaintext via the `private_key` property (or peer `public_key`):
#      good for kitchen + bootstrap dev iteration.
#   2. Vault: leave `private_key` nil and set `vault_path` (KV v2 path).
#      Resource reads the token Vault Agent maintains at
#      /run/vault-agent/token and calls chef's native
#      `secret(service: :hashi_vault, ...)`. Same pattern per-peer
#      (`vault_path` on the peer hash).
#
# Properties:
#   name        - Interface name; doubles as the wg-quick@<name>.service unit.
#   address     - CIDR (e.g. "10.200.0.14/24") (required).
#   listen_port - UDP port; nil for client-only.
#   mtu         - MTU; nil to omit (default kernel behaviour).
#   private_key - Literal private key (overrides Vault if set).
#   vault_path  - KV v2 path for the private key (used when private_key is nil).
#   vault_field - Field name within the vault secret (default 'private_key').
#   post_up     - Array of shell commands rendered as PostUp = lines.
#   post_down   - Array of shell commands rendered as PostDown = lines.
#   peers       - Array of Hashes (see template for accepted keys).
# -------------------------------------------------------------------------------

unified_mode true

provides :wireguard_interface

property :address,     String, required: true
property :listen_port, [Integer, nil]
property :mtu,         [Integer, nil]
property :private_key, [String, nil], sensitive: true
property :vault_path,  [String, nil]
property :vault_field, String, default: 'private_key'
property :post_up,     Array,  default: []
property :post_down,   Array,  default: []
property :peers,       Array,  default: []

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Resolve key material then render + bring up the interface
# -------------------------------------------------------------------------------

action :configure do
  resolved_private = resolve_private_key(new_resource)
  resolved_peers   = new_resource.peers.map { |p| resolve_peer_public_key(p) }

  template "/etc/wireguard/#{new_resource.name}.conf" do
    source 'wg.conf.erb'
    owner  'root'
    group  'root'
    mode   '0600'
    sensitive true
    variables(
      address: new_resource.address,
      listen_port: new_resource.listen_port,
      mtu: new_resource.mtu,
      private_key: resolved_private,
      post_up: new_resource.post_up,
      post_down: new_resource.post_down,
      peers: resolved_peers
    )
    notifies :run, "execute[reload wg-quick@#{new_resource.name}]", :delayed
  end

  # --- :enable only; :start fails when the kernel interface already exists. ---
  service "wg-quick@#{new_resource.name}" do
    action :enable
  end

  # --- down (cleanup) + reset-failed (clear orphan state) + up (the only step whose exit code matters). ---
  execute "reload wg-quick@#{new_resource.name}" do
    command "bash -c 'wg-quick down #{new_resource.name} 2>/dev/null || true; systemctl reset-failed wg-quick@#{new_resource.name} 2>/dev/null || true; wg-quick up #{new_resource.name}'"
    action :nothing
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Tear an interface down
# -------------------------------------------------------------------------------

action :remove do
  service "wg-quick@#{new_resource.name}" do
    action %i(disable stop)
  end

  file "/etc/wireguard/#{new_resource.name}.conf" do
    action :delete
  end
end

action_class do
  # --- Pick literal private_key if set, else fetch from Vault via munchbox_lib's vault_fetch helper ---
  def resolve_private_key(res)
    return res.private_key if res.private_key
    raise "wireguard_interface[#{res.name}]: neither private_key nor vault_path is set" unless res.vault_path

    vault_fetch(res.vault_path, res.vault_field)
  end

  # --- Same idea per-peer; mutates a copy so the original attribute hash isn't touched ---
  def resolve_peer_public_key(peer)
    p = peer.dup
    return p if p['public_key']
    raise "wireguard peer '#{p['name']}': neither public_key nor vault_path is set" unless p['vault_path']

    p['public_key'] = vault_fetch(p['vault_path'], p.fetch('vault_field', 'public_key'))
    p
  end
end
