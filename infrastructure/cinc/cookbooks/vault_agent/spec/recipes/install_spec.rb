# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'vault_agent::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(vault_agent_install)).converge('vault_agent::install')
  end

  it 'declares the vault_agent_install resource' do
    expect(chef_run).to install_vault_agent_install('vault')
  end

  it 'registers the hashicorp apt repo' do
    expect(chef_run).to add_apt_repository('hashicorp')
      .with(uri: 'https://apt.releases.hashicorp.com')
  end

  it 'installs the vault package' do
    expect(chef_run).to install_apt_package('vault')
  end

  it 'masks the upstream vault.service (server-mode) unit' do
    expect(chef_run).to mask_systemd_unit('vault.service')
  end

  it 'creates /etc/vault.d with 0700 root:root' do
    expect(chef_run).to create_directory('/etc/vault.d')
      .with(owner: 'root', group: 'root', mode: '0700')
  end

  it 'waits for the apt lock before touching apt' do
    expect(chef_run).to wait_munchbox_base_apt_lock_wait('vault_agent_install')
  end
end
