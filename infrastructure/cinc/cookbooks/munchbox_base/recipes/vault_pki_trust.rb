# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: vault_pki_trust
#
# Trust the Vault PKI intermediate CA at both the nomad-referenced path
# and the system trust store (so docker pulls from registry.service.consul
# work). Requires vault-agent; include AFTER role[vault_agent] and BEFORE
# docker::install in the run_list.
# -------------------------------------------------------------------------------

cfg = node[cookbook]['vault_pki_trust']

munchbox_base_vault_pki_trust 'baseline' do
  mount         cfg['mount']
  destinations  cfg['destinations']
  reload_docker cfg['reload_docker']
  stale_paths   cfg['stale_paths']
end
