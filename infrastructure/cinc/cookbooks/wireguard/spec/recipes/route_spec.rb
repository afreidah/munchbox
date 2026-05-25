# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# route recipe spec -- steps into wireguard_route to cover the legacy-path
# sweep and the wireguard-route.service systemd unit.
# -------------------------------------------------------------------------------

RSpec.describe 'wireguard::route' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(wireguard_route)).converge(described_recipe)
  end

  it 'declares the wireguard_route resource' do
    expect(chef_run).to configure_wireguard_route('baseline')
      .with(network: '10.200.0.0/24', gateway: '192.168.68.49')
  end

  it 'sweeps the legacy ansible-managed ifupdown file' do
    expect(chef_run).to delete_file('/etc/network/interfaces.d/wireguard-route')
  end

  it 'creates + enables + starts the wireguard-route.service oneshot unit' do
    expect(chef_run).to create_systemd_unit('wireguard-route.service')
    expect(chef_run).to enable_systemd_unit('wireguard-route.service')
    expect(chef_run).to start_systemd_unit('wireguard-route.service')
  end

  it 'bakes the network + gateway into the unit ExecStart' do
    unit = chef_run.systemd_unit('wireguard-route.service')
    expect(unit.content).to include('ExecStart=/sbin/ip route replace 10.200.0.0/24 via 192.168.68.49')
    expect(unit.content).to include('ExecStop=-/sbin/ip route del 10.200.0.0/24 via 192.168.68.49')
  end

  context 'with the gateway flipped to a different ingress VIP' do
    cached(:other_run) do
      ChefSpec::SoloRunner.new(step_into: %w(wireguard_route)) do |node|
        node.normal['wireguard']['route']['gateway'] = '192.168.68.61'
      end.converge(described_recipe)
    end

    it 'bakes the new gateway into the unit ExecStart' do
      unit = other_run.systemd_unit('wireguard-route.service')
      expect(unit.content).to include('via 192.168.68.61')
    end
  end
end
