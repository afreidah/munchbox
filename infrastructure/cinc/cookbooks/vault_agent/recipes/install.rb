# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_agent
# Recipe:: install
# -------------------------------------------------------------------------------

i = node[cookbook]['install']

vault_agent_install 'vault' do
  package_name       i['package_name']
  apt_repo_uri       i['apt_repo_uri']
  apt_repo_key       i['apt_repo_key']
  install_binary     i['install_binary']
  mask_vault_service i['mask_vault_service']
  config_dir         node[cookbook]['config_dir']
end
