# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: sshd
#
# Applies sshd hardening from node attributes. Templates
# /etc/ssh/sshd_config end-to-end and enables+starts sshd. No Vault
# dependency -- safe to run on any node, at any point in a converge.
#
# SSH CA wiring lives in the sshd_ca recipe (separate so it can run
# after vault_agent::configure has populated /run/vault-agent/token).
# -------------------------------------------------------------------------------

munchbox_base_sshd 'baseline' do
  settings node[cookbook]['ssh'].to_hash
  action   :configure
end
