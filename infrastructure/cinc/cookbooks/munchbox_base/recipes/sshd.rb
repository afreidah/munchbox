# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: sshd
#
# Applies sshd hardening from node attributes by templating
# /etc/ssh/sshd_config end-to-end. Restarts sshd when the config changes.
# -------------------------------------------------------------------------------

munchbox_base_sshd 'baseline' do
  settings node[cookbook]['ssh'].to_hash
end
