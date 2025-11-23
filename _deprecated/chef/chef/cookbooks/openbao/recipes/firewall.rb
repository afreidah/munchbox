# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  firewall.rb — Configures Consul network access via firewall rules
#
#  Defines and applies all required Consul TCP/UDP ports using the firewall cookbook.
# ------------------------------------------------------------------------------

include_recipe 'firewall'

Array(node['consul']['openbao_firewall_rules']).each do |rule|
  name     = rule[:name]     || rule['name'] || 'consul-rule'
  port     = rule[:port]     || rule['port']     # may be nil => all ports
  protocol = rule[:protocol] || rule['protocol'] # "tcp"/"udp" or :tcp/:udp or nil
  source   = rule[:source]   || rule['source'] || '192.168.68.0/24'

  # Coerce "tcp"/"udp" -> :tcp/:udp, leave nil as nil
  protocol = protocol.nil? ? nil : protocol.to_s.strip.to_sym

  firewall_rule name do
    command  :allow
    source   source
    port     port unless port.nil?
    protocol protocol unless protocol.nil?
  end
end
