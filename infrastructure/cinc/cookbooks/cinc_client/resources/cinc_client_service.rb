# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Resource:: cinc_client_service
#
# Installs the cinc-client.service + cinc-client.timer systemd units via
# chef's built-in `systemd_unit` resource. Daemon-reload fires
# automatically when content changes (systemd_unit's `triggers_reload`
# default). Timer enable/start/stop is gated on `timer_enabled` so kitchen
# + first-time provisioning can keep it stopped while still installing
# the units; production flips it on after first-run registration is
# verified.
#
# Properties:
#   timer_enabled - When true, timer is enabled + started; when false, disabled + stopped (required).
#   on_calendar   - systemd OnCalendar spec (e.g. `hourly`, `*:0/30`) (required).
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_client_service

property :timer_enabled, [true, false], required: true
property :on_calendar,   String,                  required: true

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Install both units, gate timer enable/start on the attribute
# -------------------------------------------------------------------------------

action :configure do
  # --- Oneshot service triggered by the timer; never enabled directly ---
  systemd_unit 'cinc-client.service' do
    content <<~UNIT
      [Unit]
      Description=Cinc Client periodic run
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=oneshot
      ExecStart=/usr/bin/cinc-client
    UNIT
    action :create
  end

  # --- Timer drives the periodic invocation; enabled/started iff opt-in ---
  systemd_unit 'cinc-client.timer' do
    content <<~UNIT
      [Unit]
      Description=Run cinc-client periodically

      [Timer]
      OnCalendar=#{new_resource.on_calendar}
      Persistent=true

      [Install]
      WantedBy=timers.target
    UNIT
    action(new_resource.timer_enabled ? %i(create enable start) : %i(create disable stop))
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Stop + tear down both units
# -------------------------------------------------------------------------------

action :remove do
  systemd_unit 'cinc-client.timer' do
    action %i(disable stop delete)
  end

  systemd_unit 'cinc-client.service' do
    action :delete
  end
end
