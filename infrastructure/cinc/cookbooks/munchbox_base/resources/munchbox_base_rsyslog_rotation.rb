# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_rsyslog_rotation
#
# Owns /etc/logrotate.d/rsyslog. Replaces the stock Ubuntu weekly/4-gen
# rotation with a tighter daily + size-trigger config to bound /var/log
# growth on disk-constrained nodes (oracle-arm-1 hit 3.6 GB syslog.1).
#
# Properties (all optional except log_files):
#   config_path   - Logrotate fragment to manage. Default /etc/logrotate.d/rsyslog.
#   log_files     - Array of log paths the stanza applies to. REQUIRED.
#   rotate        - Generations to keep. Default 7.
#   frequency     - 'daily' / 'weekly' / 'monthly'. Default 'daily'.
#   size          - Out-of-cycle rotation trigger (e.g. '200M'). nil to omit.
#   compress      - Bool, default true.
#   delaycompress - Bool, default true.
#   missingok     - Bool, default true.
#   notifempty    - Bool, default true.
#   su_user       - Logrotate su user. Default 'root'.
#   su_group      - Logrotate su group. Default 'syslog'.
#   postrotate    - Postrotate script body. Default invokes rsyslog-rotate.
#   force_on_change - Run `logrotate -f` immediately on template change so
#                     pre-existing oversize files get drained on first install.
#                     Default true.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_rsyslog_rotation

property :config_path,     String,                default: '/etc/logrotate.d/rsyslog'
property :log_files,       Array,                 required: true
property :rotate,          Integer,               default: 7
property :frequency,       String,                default: 'daily', equal_to: %w(daily weekly monthly)
property :size,            [String, NilClass],    default: '200M'
property :compress,        [true, false], default: true
property :delaycompress,   [true, false], default: true
property :missingok,       [true, false], default: true
property :notifempty,      [true, false], default: true
property :su_user,         String,                default: 'root'
property :su_group,        String,                default: 'syslog'
property :postrotate,      String,                default: '/usr/lib/rsyslog/rsyslog-rotate'
property :force_on_change, [true, false], default: true

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Template the fragment; optionally force-rotate on change
# -------------------------------------------------------------------------------

action :configure do
  template new_resource.config_path do
    source 'logrotate-rsyslog.erb'
    cookbook 'munchbox_base'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(
      log_files: new_resource.log_files,
      rotate: new_resource.rotate,
      frequency: new_resource.frequency,
      size: new_resource.size,
      compress: new_resource.compress,
      delaycompress: new_resource.delaycompress,
      missingok: new_resource.missingok,
      notifempty: new_resource.notifempty,
      su_user: new_resource.su_user,
      su_group: new_resource.su_group,
      postrotate: new_resource.postrotate
    )
    notifies :run, "execute[force-rotate #{new_resource.config_path}]", :immediately if new_resource.force_on_change
  end

  execute "force-rotate #{new_resource.config_path}" do
    command "logrotate -f #{new_resource.config_path}"
    action :nothing
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Delete the fragment; stock Ubuntu default takes over again
# -------------------------------------------------------------------------------

action :remove do
  file new_resource.config_path do
    action :delete
  end
end
