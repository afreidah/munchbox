# frozen_string_literal: true

include_recipe 'firewall'

## Raft (server RPC)
firewall_rule 'consul-raft' do
  port     8300
  protocol :tcp
  source   '192.168.1.0/24'
  command  :allow
end

## Serf LAN gossip
%w(tcp udp).each do |proto|
  firewall_rule "consul-serf-lan-#{proto}" do
    port     8301
    protocol proto.to_sym
    source   '192.168.1.0/24'
    command  :allow
  end
end

## Serf WAN gossip (if you ever span multiple DCs)
%w(tcp udp).each do |proto|
  firewall_rule "consul-serf-wan-#{proto}" do
    port     8302
    protocol proto.to_sym
    source   '192.168.1.0/24'
    command  :allow
  end
end

## HTTP API & Web UI
firewall_rule 'consul-http' do
  port     8500
  protocol :tcp
  source   '192.168.1.0/24'
  command  :allow
end

## DNS interface (service discovery)
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

