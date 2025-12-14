# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Ceph Cookbook - Firewall Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures firewall rules for Ceph cluster communication ports.
# -------------------------------------------------------------------------------

# --- Ensure Firewall Resource Exists ---

firewall 'default' do
  action :nothing
end

# --------------------------------------------------------------------
# Inputs / Defaults
# --------------------------------------------------------------------

allowed_cidrs = Array(node['ceph']['allowed_cidrs'])

# --------------------------------------------------------------------
# Ceph Monitor (3300/tcp, 6789/tcp)
# --------------------------------------------------------------------

[3300, 6789].each do |port|
  allowed_cidrs.each do |cidr|
    firewall_rule "ceph-mon-#{port}-#{cidr}" do
      port     port
      protocol :tcp
      source   cidr
      command  :allow
    end
  end
end

# --------------------------------------------------------------------
# Ceph OSDs (6800-7300/tcp)
# --------------------------------------------------------------------

allowed_cidrs.each do |cidr|
  firewall_rule "ceph-osd-#{cidr}" do
    port     6800..7300
    protocol :tcp
    source   cidr
    command  :allow
  end
end

# --------------------------------------------------------------------
# Ceph Manager (6800-7300/tcp - included in OSD range)
# --------------------------------------------------------------------

# Note: Ceph managers use dynamic ports in the OSD range

# --------------------------------------------------------------------
# Prometheus Metrics (9283/tcp)
# --------------------------------------------------------------------

prometheus_enabled = node.dig('ceph', 'prometheus', 'enabled') ? true : false
prometheus_port    = node['ceph']['prometheus']['port']

if prometheus_enabled
  allowed_cidrs.each do |cidr|
    firewall_rule "ceph-prometheus-#{cidr}" do
      port     prometheus_port
      protocol :tcp
      source   cidr
      command  :allow
    end
  end
end

# --------------------------------------------------------------------
# Ceph Dashboard (8443/tcp - Optional)
# --------------------------------------------------------------------

skip_dashboard = node.dig('ceph', 'skip_dashboard') ? true : false

unless skip_dashboard
  allowed_cidrs.each do |cidr|
    firewall_rule "ceph-dashboard-#{cidr}" do
      port     8443
      protocol :tcp
      source   cidr
      command  :allow
    end
  end
end
