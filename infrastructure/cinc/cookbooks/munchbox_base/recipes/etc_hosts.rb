# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: etc_hosts
#
# Renders the MUNCHBOX cluster block in /etc/hosts from chef-search.
# -------------------------------------------------------------------------------

cfg = node[cookbook]['etc_hosts']

munchbox_base_etc_hosts 'baseline' do
  hosts_path        cfg['hosts_path']
  domain            cfg['domain']
  marker_begin      cfg['marker_begin']
  marker_end        cfg['marker_end']
  ip_attribute_path cfg['ip_attribute_path']
  cloud_init_dropin cfg['cloud_init_dropin']
  static_entries    cfg['static_entries']
end
