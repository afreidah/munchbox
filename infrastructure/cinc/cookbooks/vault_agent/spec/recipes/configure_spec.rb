# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'vault_agent::configure' do
  # --- Stub the encrypted data bag fetch the recipe makes against cinc-server ---
  before do
    allow_any_instance_of(Chef::Recipe).to receive(:data_bag_item)
      .with('vault_agent', anything)
      .and_return('role_id' => 'rid-test', 'secret_id' => 'sid-test')
  end

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(vault_agent_configure)).converge('vault_agent::configure')
  end

  it 'declares the vault_agent_configure resource' do
    expect(chef_run).to configure_vault_agent_configure('vault')
  end

  it 'creates /etc/vault.d with 0700 root:root' do
    expect(chef_run).to create_directory('/etc/vault.d')
      .with(owner: 'root', group: 'root', mode: '0700')
  end

  it 'drops role_id from the data bag at /etc/vault.d/role_id with 0640 root:root' do
    expect(chef_run).to create_file('/etc/vault.d/role_id')
      .with(owner: 'root', group: 'root', mode: '0640', content: 'rid-test')
  end

  it 'drops secret_id from the data bag at /etc/vault.d/secret_id with 0640 root:root' do
    expect(chef_run).to create_file('/etc/vault.d/secret_id')
      .with(owner: 'root', group: 'root', mode: '0640', content: 'sid-test')
  end

  it 'templates /etc/vault.d/agent.hcl with the vault address + auth mount' do
    expect(chef_run).to create_template('/etc/vault.d/agent.hcl')
      .with(owner: 'root', group: 'root', mode: '0640')
    template = chef_run.template('/etc/vault.d/agent.hcl')
    expect(template.variables[:vault_addr]).to eq('https://goren.munchbox.cc:8200')
    expect(template.variables[:auth_mount]).to eq('auth/chef-approle')
  end

  it 'installs + enables + starts the vault-agent.service systemd unit' do
    expect(chef_run).to create_systemd_unit('vault-agent.service')
    expect(chef_run).to enable_systemd_unit('vault-agent.service')
    expect(chef_run).to start_systemd_unit('vault-agent.service')
  end

  it 'restarts vault-agent.service when role_id changes (delayed)' do
    expect(chef_run.file('/etc/vault.d/role_id'))
      .to notify('systemd_unit[vault-agent.service]').to(:restart).delayed
  end

  it 'restarts vault-agent.service when agent.hcl changes (delayed)' do
    expect(chef_run.template('/etc/vault.d/agent.hcl'))
      .to notify('systemd_unit[vault-agent.service]').to(:restart).delayed
  end

  it 'declares the wait-for-sink ruby_block so downstream cookbooks can rely on /run/vault-agent/token in the same converge' do
    expect(chef_run).to run_ruby_block('wait for vault-agent token sink at /run/vault-agent/token')
  end
end
