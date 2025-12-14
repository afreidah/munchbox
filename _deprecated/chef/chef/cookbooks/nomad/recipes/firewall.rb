# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Nomad Cookbook - Firewall Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures firewall rules for Nomad cluster communication and services.
# -------------------------------------------------------------------------------

# --- Include & Install Firewall ---

include_recipe 'firewall'

firewall 'default' do
  action :install
end

# --- Inputs / Defaults ---

allowed_cidrs = Array(node['nomad']['allowed_cidrs'])
server_node   = node.dig('nomad', 'server', 'enabled') ? true : false

# --- Nomad HTTP API & Web UI (4646/tcp) ---

allowed_cidrs.each do |cidr|
  firewall_rule "nomad-ui-#{cidr}" do
    port     4646
    protocol :tcp
    source   cidr
    command  :allow
  end
end

# --- Nomad gRPC/RPC (Clients <-> Servers) (4647/tcp) ---

allowed_cidrs.each do |cidr|
  firewall_rule "nomad-rpc-#{cidr}" do
    port     4647
    protocol :tcp
    source   cidr
    command  :allow
  end
end

# --- Nomad Serf Gossip (Servers only) (4648/tcp, 4648/udp) ---

if server_node
  %w(tcp udp).each do |proto|
    allowed_cidrs.each do |cidr|
      firewall_rule "nomad-serf-#{proto}-#{cidr}" do
        port     4648
        protocol proto.to_sym
        source   cidr
        command  :allow
      end
    end
  end
end

# --- Nomad port 80 for traefik ---

if server_node
  %w(tcp udp).each do |proto|
    allowed_cidrs.each do |cidr|
      firewall_rule "nomad-traefik-ingress-#{proto}-#{cidr}" do
        port     80
        protocol proto.to_sym
        source   cidr
        command  :allow
      end
    end
  end
end

# --- Nomad port 8112 for deluge ---

if server_node
  %w(tcp udp).each do |proto|
    allowed_cidrs.each do |cidr|
      firewall_rule "deluge-ingress-#{proto}-#{cidr}" do
        port     8112
        protocol proto.to_sym
        source   cidr
        command  :allow
      end
    end
  end
end
