# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec -- steps into vault_install so the underlying
# user/group/dir/remote_file/execute resources are covered.
# -------------------------------------------------------------------------------

RSpec.describe 'vault::install' do
  let(:version_check) do
    "test -x /usr/local/bin/vault && /usr/local/bin/vault version | grep -q 'Vault v2.0.1'"
  end

  cached(:chef_run) do
    stub_command(version_check).and_return(false)
    ChefSpec::SoloRunner.new(step_into: %w(vault_install)).converge(described_recipe)
  end

  it 'declares the vault_install resource' do
    expect(chef_run).to install_vault_install('vault')
      .with(
        version: '2.0.1',
        bin_path: '/usr/local/bin/vault',
        user: 'vault',
        group: 'vault',
        config_dir: '/etc/vault.d',
        data_dir: '/opt/vault/data',
        tls_dir: '/etc/vault.d/tls'
      )
  end

  it 'creates the vault system group' do
    expect(chef_run).to create_group('vault').with(system: true)
  end

  it 'creates the vault system user with the no-login shell' do
    expect(chef_run).to create_user('vault')
      .with(group: 'vault', system: true, shell: '/bin/false', manage_home: false)
  end

  it 'creates config + data + tls dirs as vault:vault 0750' do
    %w(/etc/vault.d /opt/vault/data /etc/vault.d/tls).each do |d|
      expect(chef_run).to create_directory(d)
        .with(owner: 'vault', group: 'vault', mode: '0750', recursive: true)
    end
  end

  it 'installs unzip (needed to extract the release archive)' do
    expect(chef_run).to install_package('unzip')
  end

  it 'fetches the vault release archive' do
    expect(chef_run).to create_remote_file('/tmp/vault_2.0.1_linux_amd64.zip')
      .with(source: 'https://releases.hashicorp.com/vault/2.0.1/vault_2.0.1_linux_amd64.zip', mode: '0644')
  end

  it 'extracts the archive via the install-vault execute resource' do
    expect(chef_run).to run_execute('install vault 2.0.1')
  end

  it 'declares the consul-group append (action :modify, only_if-gated)' do
    # --- group resource is always declared; the only_if guard skips the action
    #     at run time when consul group doesn't exist on the node.
    resource = chef_run.find_resources(:group).find { |r| r.name == 'consul' }
    expect(resource).not_to be_nil
    expect(resource.members).to eq(['vault'])
    expect(resource.append).to be true
  end

  context 'when the vault binary at the pinned version is already on disk' do
    cached(:idempotent_run) do
      stub_command(
        "test -x /usr/local/bin/vault && /usr/local/bin/vault version | grep -q 'Vault v2.0.1'"
      ).and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(vault_install)).converge(described_recipe)
    end

    it 'skips re-downloading the archive' do
      expect(idempotent_run.remote_file('/tmp/vault_2.0.1_linux_amd64.zip')).to do_nothing
    end

    it 'skips re-extracting via the execute resource' do
      expect(idempotent_run.execute('install vault 2.0.1')).to do_nothing
    end
  end
end
