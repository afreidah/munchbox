# frozen_string_literal: true

# Cookbook:: nomad
# Recipe:: firewall
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#

# =========================
# Include Firewall Cookbook
# =========================

include_recipe 'firewall'

# =========================
# Nomad HTTP API & Web UI
# =========================

firewall_rule 'nomad-ui' do
  port     4646
  protocol :tcp
  source   '192.168.1.0/24'
  command  :allow
end

# =========================
# Nomad gRPC/RPC (Clients ↔ Servers)
# =========================

firewall_rule 'nomad-rpc' do
  port     4647
  protocol :tcp
  source   '192.168.1.0/24'
  command  :allow
end

# =========================
# Nomad Serf Gossip (LAN & WAN)
# =========================

%w(tcp udp).each do |proto|
  firewall_rule "nomad-serf-#{proto}" do
    port     4648
    protocol proto.to_sym
    source   '192.168.1.0/24'
    command  :allow
  end
end
