# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  firewall.rb — Configures Consul network access via firewall rules
#
#  Defines and applies all required Consul TCP/UDP ports using the firewall cookbook.
# ------------------------------------------------------------------------------

include_recipe 'firewall'

# --- Define Consul firewall rules as an array of hashes ---
consul_firewall_rules = [
  { name: 'consul-raft',          port: 8300, protocol: :tcp },
  { name: 'consul-serf-lan-tcp',  port: 8301, protocol: :tcp },
  { name: 'consul-serf-lan-udp',  port: 8301, protocol: :udp },
  { name: 'consul-serf-wan-tcp',  port: 8302, protocol: :tcp },
  { name: 'consul-serf-wan-udp',  port: 8302, protocol: :udp },
  { name: 'consul-http',          port: 8500, protocol: :tcp },
  { name: 'consul-dns-tcp',       port: 8600, protocol: :tcp },
  { name: 'consul-dns-udp',       port: 8600, protocol: :udp },
]

consul_firewall_rules.each do |rule|
  firewall_rule rule[:name] do
    port     rule[:port]
    protocol rule[:protocol]
    source   '192.168.1.0/24'
    command  :allow
  end
end
