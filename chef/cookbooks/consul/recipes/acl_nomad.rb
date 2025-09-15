# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: consul
# Recipe:: acl_nomad
# Purpose:: Ensure Nomad Consul ACL policies exist; optionally mint tokens once.
# --------------------------------------------------------------------

# TODO re-token here...old token is missing so can't run this until I update
# --- Configuration knobs (set these in role/env or attrs) ---
provisioner  = node['consul']['acl']['provisioner']   # run token mint here? (true on exactly one node)
mgmt_secret  = nil

# Obtain management token from Vault/databag (root-only, never commit)
begin
  mgmt_secret = chef_vault_item('consul', 'management')['token']
rescue
  mgmt_secret = (data_bag_item('consul', 'management')['token'] rescue nil)
end

raise 'Consul ACL management token is required for policy management' if mgmt_secret.to_s.empty?

# Helper to run consul CLI with token (avoids repeating env everywhere)
consul_env = { 'CONSUL_HTTP_TOKEN' => mgmt_secret }

# --------------------------------------------------------------------
# Render policy files (for audit/versioning)
# --------------------------------------------------------------------
directory '/etc/consul.d/policies' do
  owner 'root'
  group 'root'
  mode '0750'
  recursive true
end

template '/etc/consul.d/policies/nomad-server.hcl' do
  source 'acl/nomad-server.hcl.erb'
  owner  'root'
  group  'root'
  mode   '0640'
end

template '/etc/consul.d/policies/nomad-client.hcl' do
  source 'acl/nomad-client.hcl.erb'
  owner  'root'
  group  'root'
  mode   '0640'
end

# --------------------------------------------------------------------
# Ensure policies exist (idempotent)
# --------------------------------------------------------------------
execute 'consul-acl-policy-create-nomad-server' do
  command 'consul acl policy create -name nomad-server -rules @/etc/consul.d/policies/nomad-server.hcl'
  environment(consul_env)
  # If policy exists, update its rules to match (idempotent reconcile)
  not_if 'consul acl policy read -name nomad-server >/dev/null 2>&1', environment: consul_env
end

execute 'consul-acl-policy-update-nomad-server' do
  command 'consul acl policy update -name nomad-server -rules @/etc/consul.d/policies/nomad-server.hcl'
  environment(consul_env)
  only_if 'consul acl policy read -name nomad-server >/dev/null 2>&1', environment: consul_env
end

execute 'consul-acl-policy-create-nomad-client' do
  command 'consul acl policy create -name nomad-client -rules @/etc/consul.d/policies/nomad-client.hcl'
  environment(consul_env)
  not_if 'consul acl policy read -name nomad-client >/dev/null 2>&1', environment: consul_env
end

execute 'consul-acl-policy-update-nomad-client' do
  command 'consul acl policy update -name nomad-client -rules @/etc/consul.d/policies/nomad-client.hcl'
  environment(consul_env)
  only_if 'consul acl policy read -name nomad-client >/dev/null 2>&1', environment: consul_env
end

# --------------------------------------------------------------------
# Optional: Mint Nomad server/client tokens ONCE and store them securely.
# Gate this to exactly one node (acl provisioner) to avoid duplicates.
# --------------------------------------------------------------------
if provisioner
  # Create server token unless already in Vault/databag
  begin
    server_item = chef_vault_item('consul', 'nomad_server')
  rescue
    server_item = (data_bag_item('consul', 'nomad_server') rescue nil)
  end

  execute 'consul-acl-token-create-nomad-server' do
    command 'consul acl token create -description "Nomad Server Token" -policy-name nomad-server -format=json > /root/nomad_server_token.json'
    environment(consul_env)
    sensitive true
    not_if { server_item } # skip if already present
  end

  ruby_block 'save-nomad-server-token' do
    block do
      require 'json'
      token_json = JSON.parse(File.read('/root/nomad_server_token.json'))
      secret_id  = token_json['SecretID']
      raise 'No SecretID in Nomad server token response' if secret_id.to_s.empty?

      # Persist to Vault or databag (example uses databag; switch to chef-vault in your env)
      bag = Chef::DataBagItem.new
      bag.data_bag('consul')
      bag.raw_data = { 'id' => 'nomad_server', 'token' => secret_id }
      bag.save
      File.write('/root/nomad_server_token.saved', Time.now.utc.to_s)
      File.chmod(0o600, '/root/nomad_server_token.saved')
    end
    only_if { ::File.exist?('/root/nomad_server_token.json') && !server_item }
  end

  # Create client token unless already in Vault/databag
  begin
    client_item = chef_vault_item('consul', 'nomad_client')
  rescue
    client_item = (data_bag_item('consul', 'nomad_client') rescue nil)
  end

  execute 'consul-acl-token-create-nomad-client' do
    command 'consul acl token create -description "Nomad Client Token" -policy-name nomad-client -format=json > /root/nomad_client_token.json'
    environment(consul_env)
    sensitive true
    not_if { client_item }
  end

  ruby_block 'save-nomad-client-token' do
    block do
      require 'json'
      token_json = JSON.parse(File.read('/root/nomad_client_token.json'))
      secret_id  = token_json['SecretID']
      raise 'No SecretID in Nomad client token response' if secret_id.to_s.empty?

      bag = Chef::DataBagItem.new
      bag.data_bag('consul')
      bag.raw_data = { 'id' => 'nomad_client', 'token' => secret_id }
      bag.save
      File.write('/root/nomad_client_token.saved', Time.now.utc.to_s)
      File.chmod(0o600, '/root/nomad_client_token.saved')
    end
    only_if { ::File.exist?('/root/nomad_client_token.json') && !client_item }
  end
end

