# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  install_spec.rb — ChefSpec tests for consul::install recipe
# ------------------------------------------------------------------------------

require 'spec_helper'

describe 'consul::install' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'debian', version: '12') do |node|
      node.normal['consul']['version']        = '1.15.2'
      node.normal['consul']['install_method'] = 'binary'
      node.normal['consul']['user']           = 'consul'
      node.normal['consul']['group']          = 'consul'
      node.normal['consul']['data_dir']       = '/var/lib/consul'
      node.normal['consul']['config_dir']     = '/etc/consul.d'
      node.normal['consul']['install_dir']    = '/usr/local/bin'
      node.normal['consul']['checksum']       = nil
    end.converge(described_recipe)
  end

  it 'includes the consul::firewall recipe' do
    expect(chef_run).to include_recipe('consul::firewall')
  end

  it 'installs consul with consul_install resource' do
    expect(chef_run).to create_consul_service('consul').with(
      user: 'consul',
      group: 'consul',
      data_dir: '/var/lib/consul',
      config_dir: '/etc/consul.d',
      install_dir: '/usr/local/bin',
      action: [:create]
    )
  end

  it 'renders consul_config resource' do
    expect(chef_run).to create_consul_config('consul').with(
      config_dir: '/etc/consul.d',
      install_dir: '/usr/local/bin',
      user: 'consul',
      group: 'consul'
    )
  end

  it 'enables and starts the consul service' do
    expect(chef_run).to enable_service('consul')
    expect(chef_run).to start_service('consul')
  end
end
