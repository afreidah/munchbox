# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Consul Cookbook - Firewall Recipe Spec
#
# Project: Munchbox / Author: Alex Freidah
#
# ChefSpec tests for consul::firewall recipe.
# -------------------------------------------------------------------------------

require 'spec_helper'

describe 'consul::firewall' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(platform: 'debian', version: '12').converge(described_recipe)
  end

  it 'includes the firewall recipe' do
    expect(chef_run).to include_recipe('firewall')
  end

  [
    { name: 'consul-raft',          port: 8300, protocol: :tcp },
    { name: 'consul-serf-lan-tcp',  port: 8301, protocol: :tcp },
    { name: 'consul-serf-lan-udp',  port: 8301, protocol: :udp },
    { name: 'consul-serf-wan-tcp',  port: 8302, protocol: :tcp },
    { name: 'consul-serf-wan-udp',  port: 8302, protocol: :udp },
    { name: 'consul-http',          port: 8500, protocol: :tcp },
    { name: 'consul-dns-tcp',       port: 8600, protocol: :tcp },
    { name: 'consul-dns-udp',       port: 8600, protocol: :udp },
  ].each do |rule|
    it "creates firewall_rule for #{rule[:name]}" do
      expect(chef_run).to create_firewall_rule(rule[:name]).with(
        port: rule[:port],
        protocol: rule[:protocol],
        source: '192.168.1.0/24',
        command: :allow
      )
    end
  end
end
