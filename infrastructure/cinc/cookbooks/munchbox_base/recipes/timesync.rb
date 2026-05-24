# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: timesync
#
# Configures systemd-timesyncd against the NTP servers in node attributes
# and ensures the service is enabled+running.
# -------------------------------------------------------------------------------

cfg = node[cookbook]['timesync']

return unless cfg['enabled']

munchbox_base_timesync 'baseline' do
  service          cfg['service']
  ntp_servers      cfg['ntp_servers']
  fallback_servers cfg['fallback_servers']
end
