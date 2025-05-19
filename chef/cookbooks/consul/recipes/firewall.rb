# frozen_string_literal: true
#
# Cookbook:: consul
# Recipe:: firewall
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Configures firewall rules for Consul cluster communication and services.
#

# =========================
# Include Firewall Cookbook
# =========================

include_recipe 'firewall'

# =========================
# Raft (Server RPC)
# =========================

firewall_rule 'consul-raft' do
  port     8300
  protocol :tcp
  source   '192.168.1.0/24'
  command  :allow
end

# =========================
# Serf LAN Gossip
# =========================

%w(tcp udp).each do |proto|
  firewall_rule "consul-serf-lan-#{proto}" do
    port     8301
    protocol proto.to_sym
    source   '192.168.1.0/24'
    command  :allow
  end
end

# =========================
# Serf WAN Gossip (for multi-DC)
# =========================

%w(tcp udp).each do |proto|
  firewall_rule "consul-serf-wan-#{proto}" do
    port     8302
    protocol proto.to_sym
    source   '192.168.1.0/24'
    command  :allow
  end
end

# =========================
# HTTP API & Web UI
# =========================

firewall_rule 'consul-http' do
  port     8500
  protocol :tcp
  source   '192.168.1.0/24'
  command  :allow
end

# =========================
# DNS Interface (Service Discovery)
# =========================

firewall_rule 'consul-dns-tcp' do
  port     8600
  protocol :tcp
  source   '192.168.1.0/24'
  command  :allow
end

firewall_rule 'consul-dns-udp' do
  port     8600
  protocol :udp
  source   '192.168.1.0/24'
  command  :allow
end
