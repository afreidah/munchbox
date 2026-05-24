# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_journald
#
# Renders a journald.conf.d drop-in to bound on-disk log size and retention,
# ensures journald is enabled+running, and restarts it when the drop-in
# changes.
#
# Properties:
#   settings - Hash of snake_case keys -> values. Keys are rendered as
#              PascalCase directives in [Journal] (e.g. system_max_use ->
#              SystemMaxUse). nil values are skipped.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_journald

property :settings, Hash, required: true

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Drop conf.d override, enable+start journald, restart on change
# -------------------------------------------------------------------------------

action :configure do
  directory '/etc/systemd/journald.conf.d' do
    owner 'root'
    group 'root'
    mode  '0755'
    recursive true
  end

  template '/etc/systemd/journald.conf.d/00-munchbox.conf' do
    source 'journald.conf.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(settings: new_resource.settings)
    notifies :restart, 'service[systemd-journald]', :delayed
  end

  service 'systemd-journald' do
    action %i(enable start)
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Remove the drop-in; restart journald so it picks up upstream defaults
# -------------------------------------------------------------------------------

action :remove do
  file '/etc/systemd/journald.conf.d/00-munchbox.conf' do
    action :delete
    notifies :restart, 'service[systemd-journald]', :delayed
  end

  service 'systemd-journald' do
    action %i(enable start)
  end
end
