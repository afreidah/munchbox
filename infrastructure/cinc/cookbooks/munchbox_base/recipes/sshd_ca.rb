# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: sshd_ca
#
# Wires the node up to the Vault SSH CA: trusted user CA pubkey,
# per-user authorized_principals files, the HostCertificate /
# TrustedUserCAKeys / AuthorizedPrincipalsFile sshd_config.d drop-in,
# and the break-glass key.
#
# Requires vault-agent to be running with a populated token sink at
# /run/vault-agent/token -- include this recipe AFTER role[vault_agent]
# in the run_list. Per-fleet roles opt nodes in by adding this recipe
# (presence in the run_list IS the toggle).
# -------------------------------------------------------------------------------

munchbox_base_sshd 'ca' do
  ca_settings node[cookbook]['ssh_ca'].to_hash
  action      :configure_ca
end
