# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_agent
# Recipe:: configure
#
# Reads AppRole role_id (shared) + secret_id (per-node) from the encrypted
# data bag item `vault_agent/<node.name>` and hands them to the
# vault_agent_configure resource.
#
# Decryption relies on /etc/cinc/encrypted_data_bag_secret being present;
# cinc_client::data_bag_secret enforces that earlier in the run_list.
# -------------------------------------------------------------------------------

creds = data_bag_item('vault_agent', node.name)

vault_agent_configure 'vault' do
  vault_addr  node[cookbook]['config']['vault_addr']
  auth_mount  node[cookbook]['config']['auth_mount']
  role_id     creds['role_id']
  secret_id   creds['secret_id']
  sink_path   node[cookbook]['config']['sink_path']
  sink_mode   node[cookbook]['config']['sink_mode']
  binary_path node[cookbook]['binary_path']
  config_dir  node[cookbook]['config_dir']
end
