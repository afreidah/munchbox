# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: rsyslog_rotation
#
# Applies the tightened /etc/logrotate.d/rsyslog fragment from node attrs.
# -------------------------------------------------------------------------------

cfg = node[cookbook]['rsyslog_rotation']

munchbox_base_rsyslog_rotation 'baseline' do
  config_path     cfg['config_path']
  log_files       cfg['log_files']
  rotate          cfg['rotate']
  frequency       cfg['frequency']
  size            cfg['size']
  compress        cfg['compress']
  delaycompress   cfg['delaycompress']
  missingok       cfg['missingok']
  notifempty      cfg['notifempty']
  su_user         cfg['su_user']
  su_group        cfg['su_group']
  postrotate      cfg['postrotate']
  force_on_change cfg['force_on_change']
end
