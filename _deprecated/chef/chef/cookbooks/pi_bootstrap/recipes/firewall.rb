# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: pi_bootstrap
# Recipe:: firewall
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Configures basic firewall rules for Raspberry Pi bootstrap.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Include Firewall Cookbook
# --------------------------------------------------------------------

include_recipe 'firewall'

# --------------------------------------------------------------------
# Allow Loopback Traffic
# --------------------------------------------------------------------

firewall_rule 'loopback' do
  protocol :tcp
  source   '127.0.0.1'
  command  :allow
end

# --------------------------------------------------------------------
# Allow SSH from Local Network
# --------------------------------------------------------------------

firewall_rule 'ssh' do
  port    22
  source  '0.0.0.0/0'
  command :allow
end
