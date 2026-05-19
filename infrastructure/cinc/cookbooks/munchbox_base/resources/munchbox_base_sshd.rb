# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_sshd
#
# Owns /etc/ssh/sshd_config end-to-end. The file is fully templated so we
# don't have to fight first-occurrence-wins precedence against whatever the
# upstream package or base image dropped in. Ensures sshd is enabled +
# running and restarts it whenever the config changes.
#
# Properties:
#   settings - Hash of snake_case keys -> values. Keys are rendered as
#              PascalCase sshd directives (e.g. permit_root_login ->
#              PermitRootLogin). nil values are skipped.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_sshd

property :settings, Hash, required: true

default_action :configure

# --- Template the whole sshd_config, enable+start sshd, restart on change ---
action :configure do
  template '/etc/ssh/sshd_config' do
    source 'sshd_config.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(settings: new_resource.settings)
    notifies :restart, 'service[ssh]', :delayed
  end

  service 'ssh' do
    action %i(enable start)
  end
end
