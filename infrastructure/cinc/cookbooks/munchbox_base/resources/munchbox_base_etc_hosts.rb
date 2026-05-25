# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_etc_hosts
#
# Renders a marker-delimited block in /etc/hosts with one entry per
# chef-managed node, sourced from chef-search. Each entry is
# `<ip> <hostname> <hostname>.<domain>`. ip_attribute_path picks which
# nested node attribute holds the cluster-facing IP per node (default
# the consul agent's bind_addr, which every chef-managed node sets).
# Also drops a cloud-init dropin to keep cloud-init from rewriting /etc/hosts on reboot.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_etc_hosts

property :hosts_path,        String, default: '/etc/hosts'
property :domain,            String, default: 'munchbox.cc'
property :marker_begin,      String, default: '# BEGIN MUNCHBOX CLUSTER HOSTS'
property :marker_end,        String, default: '# END MUNCHBOX CLUSTER HOSTS'
property :ip_attribute_path, Array,  default: %w(consul config bind_addr)
property :cloud_init_dropin, String, default: '/etc/cloud/cloud.cfg.d/99-disable-manage-hosts.cfg'

default_action :configure

action :configure do
  # --- Block cloud-init from overwriting /etc/hosts on reboot ---
  file new_resource.cloud_init_dropin do
    content "manage_etc_hosts: false\n"
    owner 'root'
    group 'root'
    mode '0644'
    only_if { ::Dir.exist?(::File.dirname(new_resource.cloud_init_dropin)) }
  end

  # --- Pull all chef-registered nodes; keep those with the configured IP attr set ---
  attr_path = new_resource.ip_attribute_path
  domain    = new_resource.domain

  entries = search(:node, '*:*').filter_map do |n|
    ip = n.dig(*attr_path)
    next nil unless ip

    short = n.name
    "#{ip}\t#{short} #{short}.#{domain}"
  end.sort

  desired_block = ([new_resource.marker_begin] + entries + [new_resource.marker_end]).join("\n")
  pattern       = /#{Regexp.escape(new_resource.marker_begin)}.*?#{Regexp.escape(new_resource.marker_end)}/m

  current  = ::File.exist?(new_resource.hosts_path) ? ::File.read(new_resource.hosts_path) : ''
  desired  = if current.match?(pattern)
               current.sub(pattern, desired_block)
             else
               "#{current.rstrip}\n\n#{desired_block}\n"
             end

  file new_resource.hosts_path do
    content desired
    owner 'root'
    group 'root'
    mode '0644'
  end
end
