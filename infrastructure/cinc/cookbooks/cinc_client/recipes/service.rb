# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Recipe:: service
#
# Installs the cinc-client.service + cinc-client.timer systemd units and
# enables/starts the timer iff `service.timer_enabled` is true. Default
# is disabled so kitchen + initial provisioning don't fire failing runs.
# -------------------------------------------------------------------------------

cinc_client_service 'cinc' do
  timer_enabled node[cookbook]['service']['timer_enabled']
  on_calendar   node[cookbook]['service']['on_calendar']
end
