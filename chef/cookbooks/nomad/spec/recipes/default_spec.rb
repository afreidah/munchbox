# frozen_string_literal: true

require 'spec_helper'

describe 'nomad::default' do
  let(:chef_run) do
    runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '22.04') do |node|
      node.normal['nomad']['version'] = '1.6.2'
      node.normal['nomad']['bin_path'] = '/usr/local/bin'
      node.normal['nomad']['checksums'] = {
        '1.10.3' => { 'amd64' => 'a161b8d59b42555d97d37f7a75c122831be485e89dfb97d16d6b60cfaec8d88b', 'arm64' => '33d29315154035295a0f735622da4322ea500e49b5f85686139e76a5e89a7ce9' },
        '1.6.2' => 'abc123',
      }
      node.normal['nomad']['config_dir'] = '/etc/nomad.d'
      node.normal['nomad']['data_dir'] = '/opt/nomad'
      node.normal['nomad']['bind_addr'] = '0.0.0.0'
      node.normal['nomad']['datacenter'] = 'dc1'
      node.normal['nomad']['server'] = { 'enabled' => true, 'servers' => ['1.2.3.4', '5.6.7.8'] }
      node.normal['nomad']['client'] = { 'enabled' => true }
      node.normal['nomad']['telemetry'] = {
        'enabled' => true,
        'collection_interval' => '1s',
        'disable_hostname' => true,
        'prometheus_metrics' => true,
        'publish_allocation_metrics' => true,
        'publish_node_metrics' => true,
      }
      node.normal['nomad']['docker'] = {
        'allow_privileged' => true,
        'volumes' => { 'enabled' => true },
        'caps' => ['NET_ADMIN'],
      }
      node.normal['nomad']['consul'] = { 'auto_join' => true }
      node.normal['nomad']['vault'] = { 'enabled' => true, 'address' => 'http://vault:8200' }
      node.normal['nomad']['user'] = 'nomad'
      node.normal['nomad']['group'] = 'nomad'
      node.normal['nomad']['cni'] = { 'enabled' => false, 'version' => '1.2.3', 'path' => '/opt/cni/bin', 'url' => 'https://example.com' }
      node.normal['nomad']['acl'] = { 'bootstrap_this_node' => true }
    end
    allow_any_instance_of(Chef::Recipe).to receive(:encrypted_data_bag_item).and_return({ 'token' => 'vault-token' })
    runner.converge(described_recipe)
  end

  it 'installs nomad' do
    expect(chef_run).to install_nomad_install('nomad').with(
      version: '1.6.2',
      bin_path: '/usr/local/bin',
      checksums: hash_including('1.6.2' => 'abc123')
    )
  end

  it 'configures nomad' do
    expect(chef_run).to apply_nomad_configure('nomad').with(
      config_dir: '/etc/nomad.d',
      data_dir: '/opt/nomad',
      bind_addr: '0.0.0.0',
      datacenter: 'dc1',
      server_enabled: true,
      client_enabled: true,
      retry_join: ['1.2.3.4:4648', '5.6.7.8:4648'],
      telemetry: hash_including('enabled' => true),
      docker: hash_including('allow_privileged' => true),
      consul_auto: true,
      vault: { 'enabled' => true, 'address' => 'http://vault:8200', 'token' => 'vault-token' },
      user: 'nomad',
      group: 'nomad',
      enable_cni: false,
      cni_version: '1.2.3',
      cni_path: '/opt/cni/bin',
      cni_url_base: 'https://example.com'
    )
  end

  it 'brings up the nomad cluster' do
    expect(chef_run).to converge_nomad_cluster('nomad').with(
      bind_addr: '0.0.0.0',
      wait_for_consul: false,
      acl_enabled: true,
      bootstrap_this: true
    )
  end
end
