# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_agent
# Resource:: vault_agent_configure
#
# Drops Vault Agent config + AppRole credentials, installs the
# vault-agent.service systemd unit, and brings it up. After this resource
# converges, vault-agent maintains a current Vault token at `sink_path`
# that downstream cookbooks read for `secret('hashi_vault', ...)`.
#
# Properties:
#   vault_addr - Vault API URL (required).
#   auth_mount - Vault AppRole mount path (default 'auth/chef-approle').
#   role_id    - Shared role_id for the chef-managed-node AppRole (required).
#   secret_id  - Per-node secret_id (required, sensitive).
#   sink_path  - Where vault-agent writes the token (default /run/vault-agent/token).
#   sink_mode  - Octal perms on the sink file (default 0640).
# -------------------------------------------------------------------------------

unified_mode true

provides :vault_agent_configure

property :vault_addr,  String,         required: true
property :auth_mount,  String,         default: 'auth/chef-approle'
property :role_id,     [String, nil]
property :secret_id,   [String, nil], sensitive: true
property :sink_path,   String,         default: '/run/vault-agent/token'
property :sink_mode,   String,         default: '0640'
property :binary_path, String,         default: '/usr/bin/vault'
property :config_dir,  String,         default: '/etc/vault.d'

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  raise "vault_agent_configure[#{new_resource.name}]: role_id is empty; check the vault_agent/<node.name> data bag item" if new_resource.role_id.to_s.empty?
  raise "vault_agent_configure[#{new_resource.name}]: secret_id is empty; check the vault_agent/<node.name> data bag item" if new_resource.secret_id.to_s.empty?

  role_id_path   = ::File.join(new_resource.config_dir, 'role_id')
  secret_id_path = ::File.join(new_resource.config_dir, 'secret_id')
  agent_hcl_path = ::File.join(new_resource.config_dir, 'agent.hcl')

  directory new_resource.config_dir do
    owner 'root'
    group 'root'
    mode  '0700'
  end

  file role_id_path do
    content   new_resource.role_id
    owner     'root'
    group     'root'
    mode      '0640'
    sensitive true
    notifies :restart, 'systemd_unit[vault-agent.service]', :delayed
  end

  file secret_id_path do
    content   new_resource.secret_id
    owner     'root'
    group     'root'
    mode      '0640'
    sensitive true
    notifies :restart, 'systemd_unit[vault-agent.service]', :delayed
  end

  template agent_hcl_path do
    source 'agent.hcl.erb'
    owner  'root'
    group  'root'
    mode   '0640'
    variables(
      vault_addr:     new_resource.vault_addr,
      auth_mount:     new_resource.auth_mount,
      sink_path:      new_resource.sink_path,
      sink_mode:      new_resource.sink_mode,
      role_id_path:   role_id_path,
      secret_id_path: secret_id_path
    )
    notifies :restart, 'systemd_unit[vault-agent.service]', :delayed
  end

  # --- RuntimeDirectory= creates /run/vault-agent each start ---
  systemd_unit 'vault-agent.service' do
    content <<~UNIT
      [Unit]
      Description=HashiCorp Vault Agent (chef AppRole auto-auth)
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=simple
      ExecStart=#{new_resource.binary_path} agent -config=#{agent_hcl_path}
      Restart=on-failure
      RestartSec=5
      User=root
      RuntimeDirectory=vault-agent
      RuntimeDirectoryMode=0750

      [Install]
      WantedBy=multi-user.target
    UNIT
    action %i(create enable start)
  end

  # --- Block until the token sink exists so downstream cookbooks don't race vault-agent's first-run AppRole login. ---
  ruby_block "wait for vault-agent token sink at #{new_resource.sink_path}" do
    block do
      deadline = Time.now + 30
      until ::File.exist?(new_resource.sink_path) && ::File.size(new_resource.sink_path).positive?
        raise "vault-agent did not write #{new_resource.sink_path} within 30s; is the Vault server reachable + AppRole creds valid?" if Time.now > deadline

        sleep 1
      end
    end
    not_if { ::File.exist?(new_resource.sink_path) && ::File.size(new_resource.sink_path).positive? }
  end
end

# -------------------------------------------------------------------------------
# Action :remove
# -------------------------------------------------------------------------------

action :remove do
  systemd_unit 'vault-agent.service' do
    action %i(disable stop delete)
  end

  %w(agent.hcl secret_id role_id).each do |name|
    file ::File.join(new_resource.config_dir, name) do
      action :delete
    end
  end
end
