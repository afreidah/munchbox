# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: resolv_conf
#
# Templates /etc/resolv.conf to point at the local dnsmasq via the host's
# primary IP. Required because nomad's docker driver mis-detects
# `nameserver 127.0.0.53` as systemd-resolved and faceplants on missing
# /run/systemd/resolve/resolv.conf when launching bridge-network allocs.
# -------------------------------------------------------------------------------

resolv = node[cookbook]['resolv_conf']

nameserver = resolv['nameserver'] || (node['global'] && node['global']['dns_endpoint_ip'])
raise 'munchbox_base::resolv_conf: nameserver is empty (set node[cookbook][:resolv_conf][:nameserver] or node[:global][:dns_endpoint_ip])' if nameserver.to_s.empty?

munchbox_base_resolv_conf 'baseline' do
  path       resolv['path']
  search     resolv['search']
  nameserver nameserver
end
