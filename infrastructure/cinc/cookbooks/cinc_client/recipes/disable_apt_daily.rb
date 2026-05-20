# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Recipe:: disable_apt_daily
#
# Stops + disables + masks Ubuntu's apt-daily.timer / apt-daily-upgrade.timer
# (and their backing services) so they don't run concurrently with cinc-client
# and grab the apt lock. Include this on chef-managed nodes where cinc-client
# owns the apt lifecycle (cloud images especially -- on oracle a stuck
# apt-daily kept the lock for days).
#
# Opt-in via role/run_list; not pulled in by default because some nodes
# legitimately want unattended-upgrades for hands-off patching between
# chef converges.
# -------------------------------------------------------------------------------

%w(
  apt-daily.timer
  apt-daily-upgrade.timer
  apt-daily.service
  apt-daily-upgrade.service
).each do |unit|
  systemd_unit unit do
    action %i(stop disable mask)
  end
end
