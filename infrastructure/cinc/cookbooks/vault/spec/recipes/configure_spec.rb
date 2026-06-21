# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec. vault_fetch is stubbed globally by spec_helper to
# return 'fake-vault-value'; specific contexts override via module_eval.
# -------------------------------------------------------------------------------

RSpec.describe 'vault::configure' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(vault_configure)) do |node|
      node.normal['vault']['config']['advertise_ip'] = '192.168.68.60'
    end.converge(described_recipe)
  end

  it 'declares the vault_configure resource keyed by "vault"' do
    expect(chef_run).to configure_vault_configure('vault')
      .with(
        advertise_ip: '192.168.68.60',
        cluster_name: 'munchbox-vault',
        api_scheme: 'https',
        api_port: 8200,
        cluster_port: 8201,
        bin_path: '/usr/local/bin/vault',
        config_dir: '/etc/vault.d',
        user: 'vault',
        group: 'vault'
      )
  end

  it 'renders /etc/vault.d/vault.hcl as vault:vault 0640' do
    expect(chef_run).to create_template('/etc/vault.d/vault.hcl')
      .with(owner: 'vault', group: 'vault', mode: '0640', sensitive: true)
  end

  it 'wires the consul-storage backend address + token into vault.hcl variables' do
    tmpl = chef_run.template('/etc/vault.d/vault.hcl')
    expect(tmpl.variables[:storage_address]).to eq('127.0.0.1:8501')
    expect(tmpl.variables[:storage_scheme]).to eq('https')
    expect(tmpl.variables[:storage_path]).to eq('vault/')
    expect(tmpl.variables[:consul_storage_token]).to eq('fake-vault-value')
  end

  it 'creates + enables (but does NOT start) the vault.service systemd unit' do
    # --- start is operator-only because shamir + unseal x3. ---
    expect(chef_run).to create_systemd_unit('vault.service')
    expect(chef_run).to enable_systemd_unit('vault.service')
    expect(chef_run).not_to start_systemd_unit('vault.service')
  end

  it 'does NOT notify vault.service to restart when restart_on_change is false (the default)' do
    expect(chef_run.template('/etc/vault.d/vault.hcl'))
      .not_to notify('systemd_unit[vault.service]').to(:restart)
  end

  context 'with restart_on_change opt-in (planned-maintenance window)' do
    let(:restart_run) do
      ChefSpec::SoloRunner.new(step_into: %w(vault_configure)) do |node|
        node.normal['vault']['config']['advertise_ip']      = '192.168.68.60'
        node.normal['vault']['config']['restart_on_change'] = true
      end.converge(described_recipe)
    end

    it 'notifies vault.service to restart (delayed) when vault.hcl changes' do
      expect(restart_run.template('/etc/vault.d/vault.hcl'))
        .to notify('systemd_unit[vault.service]').to(:restart).delayed
    end
  end

  context 'with stale_paths configured' do
    let(:sweep_run) do
      ChefSpec::SoloRunner.new(step_into: %w(vault_configure)) do |node|
        node.normal['vault']['config']['advertise_ip'] = '192.168.68.60'
        node.normal['vault']['config']['stale_paths']  = ['/etc/vault.d/vault.hcl.bak']
      end.converge(described_recipe)
    end

    it 'sweeps each stale path' do
      expect(sweep_run).to delete_file('/etc/vault.d/vault.hcl.bak')
    end
  end

  context 'with OCI KMS auto-unseal enabled' do
    let(:seal_run) do
      stub_data_bag_item('vault_unseal', 'oci_api_key').and_return('private_key' => 'PEMDATA')
      ChefSpec::SoloRunner.new(step_into: %w(vault_configure)) do |node|
        node.normal['vault']['config']['advertise_ip']        = '192.168.68.60'
        node.normal['vault']['seal']['enabled']               = true
        node.normal['vault']['seal']['key_id']                = 'ocid1.key.oc1..mock'
        node.normal['vault']['seal']['crypto_endpoint']       = 'https://crypto.mock'
        node.normal['vault']['seal']['management_endpoint']   = 'https://mgmt.mock'
        node.normal['vault']['seal']['tenancy_ocid']          = 'ocid1.tenancy.oc1..mock'
        node.normal['vault']['seal']['user_ocid']             = 'ocid1.user.oc1..mock'
        node.normal['vault']['seal']['fingerprint']           = 'aa:bb:cc'
        node.normal['vault']['seal']['region']                = 'us-phoenix-1'
      end.converge(described_recipe)
    end

    it 'creates the OCI config dir at 0700' do
      expect(seal_run).to create_directory('/etc/vault.d/.oci')
        .with(owner: 'vault', group: 'vault', mode: '0700')
    end

    it 'writes the OCI API private key from the data bag at 0600' do
      expect(seal_run).to create_file('/etc/vault.d/.oci/oci_api_key.pem')
        .with(owner: 'vault', group: 'vault', mode: '0600')
    end

    it 'renders the OCI SDK config at 0600' do
      expect(seal_run).to create_template('/etc/vault.d/.oci/config')
        .with(owner: 'vault', group: 'vault', mode: '0600')
    end

    it 'passes the ocikms seal into vault.hcl' do
      vars = seal_run.template('/etc/vault.d/vault.hcl').variables
      expect(vars[:seal_enabled]).to eq(true)
      expect(vars[:seal_key_id]).to eq('ocid1.key.oc1..mock')
    end
  end

  context 'when the consul-storage token is empty' do
    before do
      MunchboxLibVaultFetch.module_eval do
        define_method(:vault_fetch) { |_path, _field| '' }
      end
    end

    it 'raises rather than rendering an unauthenticated vault.hcl' do
      expect do
        ChefSpec::SoloRunner.new(step_into: %w(vault_configure)) do |node|
          node.normal['vault']['config']['advertise_ip'] = '192.168.68.60'
        end.converge(described_recipe)
      end.to raise_error(/consul_storage_token cannot be empty/)
    end
  end
end
