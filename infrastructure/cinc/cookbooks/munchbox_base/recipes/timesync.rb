# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: timesync
#
# Configures systemd-timesyncd against the NTP servers in node attributes
# and ensures the service is enabled+running.
# -------------------------------------------------------------------------------

munchbox_base_timesync 'baseline' do
  service          node[cookbook]['timesync']['service']
  ntp_servers      node[cookbook]['timesync']['ntp_servers']
  fallback_servers node[cookbook]['timesync']['fallback_servers']
end
