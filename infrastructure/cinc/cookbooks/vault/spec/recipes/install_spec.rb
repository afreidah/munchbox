# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers user/group/dir + consul-group membership + the hand-off to
# munchbox_lib_artifact (URL, SHA256SUMS verify url, zip target). The
# critical vault invariant: install must NEVER notify a service restart
# (vault is shamir-sealed; restart = manual unseal x3). The actual
# download/verify/unzip live in munchbox_lib_artifact (not stepped into);
# kitchen verifies the real install end-to-end.
# -------------------------------------------------------------------------------

RSpec.describe 'vault::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(vault_install)).converge(described_recipe)
  end

  let(:artifact) { chef_run.find_resource('munchbox_lib_artifact', 'vault 2.0.1') }

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

  # --- Hands off the download/verify/install to the shared artifact resource ---
  it 'delegates the install to munchbox_lib_artifact' do
    expect(chef_run).to install_munchbox_lib_artifact('vault 2.0.1')
  end

  # --- HashiCorp release archive URL (amd64 on the default chefspec kernel) ---
  it 'builds the vault release archive url' do
    expect(artifact.source).to eq('https://releases.hashicorp.com/vault/2.0.1/vault_2.0.1_linux_amd64.zip')
  end

  # --- Verifies against HashiCorp's published SHA256SUMS rather than a pinned sha ---
  it 'verifies against the published SHA256SUMS' do
    expect(artifact.sums_url).to eq('https://releases.hashicorp.com/vault/2.0.1/vault_2.0.1_SHA256SUMS')
  end

  # --- Extracts the zip into the binary's directory ---
  it 'installs the zip into /usr/local/bin' do
    expect(artifact.format).to eq(:zip)
    expect(artifact.bin_dir).to eq('/usr/local/bin')
  end

  # --- THE vault invariant: a sealed server must never be auto-restarted, so the
  #     install hands off WITHOUT any service notify. ---
  it 'never notifies a vault service restart (sealed -- restart is a planned op)' do
    expect(artifact).not_to notify('service[vault]')
  end

  it 'declares the consul-group append (action :modify, only_if-gated)' do
    # --- group resource is always declared; the only_if guard skips the action
    #     at run time when the consul group doesn't exist on the node. ---
    resource = chef_run.find_resources(:group).find { |r| r.name == 'consul' }
    expect(resource).not_to be_nil
    expect(resource.members).to eq(['vault'])
    expect(resource.append).to be true
  end
end
