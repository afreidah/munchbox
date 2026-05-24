# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Recipe:: install
#
# Installs the wireguard + wireguard-tools packages, ensures
# /etc/wireguard exists with restrictive perms, and flips on
# net.ipv4.ip_forward if requested.
# -------------------------------------------------------------------------------

wireguard_install 'wireguard' do
  packages   node[cookbook]['install']['packages'].to_a
  ip_forward node[cookbook]['install']['ip_forward']
end
