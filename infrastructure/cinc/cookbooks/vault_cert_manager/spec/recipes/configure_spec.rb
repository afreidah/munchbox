# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec
#
# Covers secret_id file, config.yaml template, systemd Restart=always
# drop-in, consul service-registration JSON, and enable+start of the
# vault-cert-manager service. vault_fetch is stubbed (lazy{} evaluates
# in the resource context).
# -------------------------------------------------------------------------------

RSpec.describe 'vault_cert_manager::configure' do
  before do
    # --- Stub both contexts; lazy{} on the file content / template variables evaluates against Chef::Resource ---
    allow_any_instance_of(Chef::Recipe).to receive(:vault_fetch).and_return('test-vault-cert-manager-secret')
    allow_any_instance_of(Chef::Resource).to receive(:vault_fetch).and_return('test-vault-cert-manager-secret')
  end

  cached(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
      node.override['vault_cert_manager']['certificates'] = [
        {
          'name'        => 'consul-client',
          'role'        => 'consul-client',
          'common_name' => 'client.munchbox.consul',
          'certificate' => '/etc/consul.d/tls/consul.crt',
          'key'         => '/etc/consul.d/tls/consul.key',
          'ttl'         => '720h',
          'alt_names'   => %w(localhost test-node),
          'ip_sans'     => %w(10.200.0.99 127.0.0.1),
          'owner'       => 'consul',
          'group'       => 'consul',
        },
      ]
    end.converge('vault_cert_manager::configure')
  end

  # --- secret_id file: sensitive, 0600, vault-fetched content ---
  it 'creates /etc/vault-cert-manager/secret_id with 0600 root:root and sensitive=true' do
    expect(chef_run).to create_file('/etc/vault-cert-manager/secret_id')
      .with(owner: 'root', group: 'root', mode: '0600', sensitive: true)
  end

  # --- secret_id change notifies daemon restart (delayed) ---
  it 'notifies vault-cert-manager restart (delayed) on secret_id change' do
    expect(chef_run.file('/etc/vault-cert-manager/secret_id'))
      .to notify('service[vault-cert-manager]').to(:restart).delayed
  end

  # --- Main config template + perms ---
  it 'renders /etc/vault-cert-manager/config.yaml with 0640 root:root and sensitive=true' do
    expect(chef_run).to create_template('/etc/vault-cert-manager/config.yaml')
      .with(owner: 'root', group: 'root', mode: '0640', sensitive: true)
  end

  # --- Cert def from node overrides flows into the template variables ---
  it 'passes the certificates list through to the template' do
    template = chef_run.template('/etc/vault-cert-manager/config.yaml')
    expect(template.variables[:certificates]).to be_an(Array)
    expect(template.variables[:certificates].first['name']).to eq('consul-client')
    expect(template.variables[:certificates].first['ip_sans']).to include('10.200.0.99')
  end

  # --- Systemd Restart=always drop-in ---
  it 'creates the systemd drop-in dir' do
    expect(chef_run).to create_directory('/etc/systemd/system/vault-cert-manager.service.d')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  it 'writes the Restart=always drop-in with 0644 root:root' do
    expect(chef_run).to create_file('/etc/systemd/system/vault-cert-manager.service.d/restart.conf')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  it 'notifies daemon-reload (immediate) + service restart (delayed) on drop-in change' do
    f = chef_run.file('/etc/systemd/system/vault-cert-manager.service.d/restart.conf')
    expect(f).to notify('execute[systemctl daemon-reload vault-cert-manager]').to(:run).immediately
    expect(f).to notify('service[vault-cert-manager]').to(:restart).delayed
  end

  # --- daemon-reload helper declared :nothing ---
  it 'declares the daemon-reload execute as :nothing' do
    expect(chef_run.execute('systemctl daemon-reload vault-cert-manager')).to do_nothing
  end

  # --- Consul service registration ---
  it 'drops /etc/consul.d/vault-cert-manager.json with 0640 consul:consul' do
    expect(chef_run).to create_template('/etc/consul.d/vault-cert-manager.json')
      .with(owner: 'consul', group: 'consul', mode: '0640')
  end

  it 'notifies consul reload (delayed) on service-file change' do
    expect(chef_run.template('/etc/consul.d/vault-cert-manager.json'))
      .to notify('service[consul]').to(:reload).delayed
  end

  # --- Daemon enabled + started ---
  it 'enables + starts vault-cert-manager.service' do
    expect(chef_run).to enable_service('vault-cert-manager')
    expect(chef_run).to start_service('vault-cert-manager')
  end

  # --- consul service handle is :nothing (consul cookbook owns its lifecycle) ---
  it 'declares the consul service as :nothing' do
    expect(chef_run.service('consul')).to do_nothing
  end
end
