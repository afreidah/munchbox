# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# vault_pki_trust recipe spec -- vault_pki_ca / vault_pki_ca_chain are
# stubbed globally in spec_helper to return fixed PEM strings.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::vault_pki_trust' do
  cached(:chef_run) do
    # --- pretend none of the destination cert files exist on the test FS so the
    #     rotate-into-backup_dir path (which does a raw ::File.rename) doesn't fire.
    allow(::File).to receive(:exist?).and_call_original
    %w(
      /usr/local/share/ca-certificates/vault-pki-ca.crt
      /opt/nomad/tls/vault-intermediate-ca.pem
      /etc/consul.d/tls/ca-chain.crt
    ).each { |p| allow(::File).to receive(:exist?).with(p).and_return(false) }
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_vault_pki_trust)).converge(described_recipe)
  end

  it 'declares the wrapping resource keyed by baseline' do
    expect(chef_run).to configure_munchbox_base_vault_pki_trust('baseline')
      .with(mount: 'pki_int')
  end

  it 'writes the system-trust CA destination (triggers update-ca-certificates)' do
    expect(chef_run).to create_file('/usr/local/share/ca-certificates/vault-pki-ca.crt')
      .with(owner: 'root', group: 'root', mode: '0644')
    expect(chef_run.file('/usr/local/share/ca-certificates/vault-pki-ca.crt').content)
      .to include('-----BEGIN CERTIFICATE-----')
  end

  it 'writes the nomad-trust CA destination' do
    expect(chef_run).to create_file('/opt/nomad/tls/vault-intermediate-ca.pem')
  end

  it 'writes the consul ca-chain destination consul:consul' do
    expect(chef_run).to create_file('/etc/consul.d/tls/ca-chain.crt')
      .with(owner: 'consul', group: 'consul', mode: '0644')
  end

  it 'fires update-ca-certificates after the system-trust dest is written' do
    expect(chef_run).to run_execute('update-ca-certificates (vault-pki pki_int)')
  end

  it 'sweeps the ansible-era stale paths from the default config' do
    expect(chef_run).to delete_file('/opt/nomad/tls/vault-ca-chain.pem')
    expect(chef_run).to delete_file('/opt/nomad/tls/nomad-agent-ca.pem')
  end

  it 'ensures each destination parent dir exists (only_if-gated; resource declared every converge)' do
    %w(/opt/nomad/tls /usr/local/share/ca-certificates /etc/consul.d/tls).each do |d|
      expect(chef_run.find_resources(:directory).map(&:name)).to include(d)
    end
  end

  it 'restarts docker after the system-trust dest changes (default reload_docker: true)' do
    expect(chef_run).to restart_service('docker')
  end
end
