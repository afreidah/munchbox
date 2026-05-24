# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_timesync
#
# Configures systemd-timesyncd via a conf.d drop-in and ensures the timesync
# service is enabled+running. Pure function of its properties.
#
# Properties:
#   service          - systemd unit to enable (default systemd-timesyncd).
#   ntp_servers      - Array of primary NTP servers (required).
#   fallback_servers - Array of fallback NTP servers (optional).
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_timesync

property :service,          String, default: 'systemd-timesyncd'
property :ntp_servers,      Array,  required: true
property :fallback_servers, Array,  default: []

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Drop conf.d override, enable+start service, restart on change
# -------------------------------------------------------------------------------

action :configure do
  directory '/etc/systemd/timesyncd.conf.d' do
    owner 'root'
    group 'root'
    mode  '0755'
    recursive true
  end

  template '/etc/systemd/timesyncd.conf.d/00-munchbox.conf' do
    source 'timesyncd.conf.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(
      ntp_servers: new_resource.ntp_servers,
      fallback_servers: new_resource.fallback_servers
    )
    notifies :restart, "service[#{new_resource.service}]", :delayed
  end

  service new_resource.service do
    action %i(enable start)
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Remove the drop-in but leave the service running
# -------------------------------------------------------------------------------

action :remove do
  file '/etc/systemd/timesyncd.conf.d/00-munchbox.conf' do
    action :delete
    notifies :restart, "service[#{new_resource.service}]", :delayed
  end

  service new_resource.service do
    action %i(enable start)
  end
end
