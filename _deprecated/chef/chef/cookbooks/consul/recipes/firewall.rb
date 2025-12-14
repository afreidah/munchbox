# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Consul Cookbook - Firewall Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures Consul network access via firewall rules for all required ports.
# -------------------------------------------------------------------------------

include_recipe 'firewall'

Array(node['consul']['consul_firewall_rules']).each do |rule|
  name     = rule[:name]     || rule['name'] || 'consul-rule'
  port     = rule[:port]     || rule['port']     # may be nil => all ports
  protocol = rule[:protocol] || rule['protocol'] # "tcp"/"udp" or :tcp/:udp or nil
  source   = rule[:source]   || rule['source'] || '0.0.0.0/0'

  # Coerce "tcp"/"udp" -> :tcp/:udp, leave nil as nil
  protocol = protocol.nil? ? nil : protocol.to_s.strip.to_sym

  firewall_rule name do
    command  :allow
    source   source
    port     port unless port.nil?
    protocol protocol unless protocol.nil?
  end
end
