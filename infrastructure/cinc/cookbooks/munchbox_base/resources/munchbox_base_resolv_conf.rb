# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_resolv_conf
#
# Manages /etc/resolv.conf to point at the local dnsmasq via the host's
# primary IP (not 127.0.0.53). See attributes/default.rb for why this
# matters for nomad's docker driver.
#
# Properties:
#   path        - Default /etc/resolv.conf.
#   search      - Search domain. Required.
#   nameserver  - Resolver IP. Required. Per-fleet usage passes the host's
#                 dnsmasq listen IP (same value as node['global']['dns_endpoint_ip']).
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_resolv_conf

property :path,       String, default: '/etc/resolv.conf'
property :search,     String, required: true
property :nameserver, String, required: true

default_action :configure

action :configure do
  template new_resource.path do
    source 'resolv_conf.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(
      search:     new_resource.search,
      nameserver: new_resource.nameserver
    )
  end
end
