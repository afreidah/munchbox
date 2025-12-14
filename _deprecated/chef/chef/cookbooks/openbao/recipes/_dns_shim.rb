# frozen_string_literal: true

# -------------------------------------------------------------------------------
# OpenBao Cookbook - DNS Shim Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Ensures node's FQDN is resolvable via /etc/hosts for OpenBao.
# -------------------------------------------------------------------------------

ruby_block 'ensure_self_fqdn_in_hosts' do
  block do
    fqdn = node['fqdn']
    ip   = `hostname -I`.to_s.split(/\s+/).first
    raise 'Could not determine primary IP' if ip.to_s.empty?

    OpenBao::Cluster.ensure_hosts_entry(ip: ip, fqdn: fqdn)
  end
end
