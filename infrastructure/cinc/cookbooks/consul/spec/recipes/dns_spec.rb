# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# dns recipe spec
#
# Covers the default (manage everything) path plus the manage_resolv_conf=false
# escape hatch. The actual dnsmasq config rendering is owned by the
# integration suite -- here we just confirm the resource graph.
# -------------------------------------------------------------------------------

RSpec.describe 'consul::dns' do
  context 'with defaults (oracle-ish: ipaddress derived)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(consul_dns)) do |node|
        node.automatic[:ipaddress] = '10.200.0.14'
      end.converge('consul::dns')
    end

    # --- Wrapping resource gets credit for coverage ---
    it 'declares the consul_dns wrapping resource' do
      expect(chef_run).to configure_consul_dns('baseline')
    end

    # --- dnsmasq installed, conflicting services stopped ---
    it 'installs dnsmasq' do
      expect(chef_run).to install_apt_package('dnsmasq')
    end

    it 'stops and disables systemd-resolved' do
      expect(chef_run).to stop_service('systemd-resolved')
      expect(chef_run).to disable_service('systemd-resolved')
    end

    it 'stops and disables avahi-daemon' do
      expect(chef_run).to stop_service('avahi-daemon')
      expect(chef_run).to disable_service('avahi-daemon')
    end

    # --- dnsmasq config template gets the host_ip from node['ipaddress'] ---
    it 'renders /etc/dnsmasq.d/consul.conf with the host IP listen address' do
      tpl = chef_run.template('/etc/dnsmasq.d/consul.conf')
      expect(tpl.variables[:host_ip]).to eq('10.200.0.14')
      expect(tpl.variables[:listen_address]).to eq('127.0.0.53')
      expect(tpl.variables[:pihole_servers]).to include('192.168.68.62', '192.168.68.64')
    end

    it 'restarts dnsmasq when the config changes' do
      expect(chef_run.template('/etc/dnsmasq.d/consul.conf'))
        .to notify('service[dnsmasq]').to(:restart).delayed
    end

    # --- /etc/resolv.conf takeover is on by default ---
    it 'renders /etc/resolv.conf pointing at the loopback dnsmasq listener' do
      tpl = chef_run.template('/etc/resolv.conf')
      expect(tpl.variables[:listen_address]).to eq('127.0.0.53')
      expect(tpl.variables[:search]).to eq('munchbox.cc')
    end

    # --- Stale old fragment is cleaned ---
    it 'deletes the legacy /etc/dnsmasq.d/10-consul.conf' do
      expect(chef_run).to delete_file('/etc/dnsmasq.d/10-consul.conf')
    end

    # --- Service lifecycle ---
    it 'enables and starts dnsmasq' do
      expect(chef_run).to enable_service('dnsmasq')
      expect(chef_run).to start_service('dnsmasq')
    end
  end

  context 'with manage_resolv_conf=false (safer first-adoption mode)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(consul_dns)) do |node|
        node.automatic[:ipaddress] = '10.200.0.14'
        node.override[:consul][:dns][:manage_resolv_conf] = false
      end.converge('consul::dns')
    end

    it 'does not touch /etc/resolv.conf' do
      expect(chef_run).to_not create_template('/etc/resolv.conf')
    end

    it 'still installs and configures dnsmasq' do
      expect(chef_run).to install_apt_package('dnsmasq')
      expect(chef_run).to create_template('/etc/dnsmasq.d/consul.conf')
    end
  end

  context 'with explicit host_ip override (e.g. WG IP not detected as primary)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(consul_dns)) do |node|
        node.automatic[:ipaddress] = '192.168.1.50'
        node.override[:consul][:dns][:host_ip] = '10.200.0.99'
      end.converge('consul::dns')
    end

    it 'prefers the attribute host_ip over node[:ipaddress]' do
      tpl = chef_run.template('/etc/dnsmasq.d/consul.conf')
      expect(tpl.variables[:host_ip]).to eq('10.200.0.99')
    end
  end

  context "with node['global']['dns_endpoint_ip'] set (shared role-level attr)" do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(consul_dns)) do |node|
        node.automatic[:ipaddress]               = '192.168.1.50'
        node.override[:global][:dns_endpoint_ip] = '10.200.0.42'
      end.converge('consul::dns')
    end

    it 'uses the global dns_endpoint_ip when consul.dns.host_ip is unset' do
      tpl = chef_run.template('/etc/dnsmasq.d/consul.conf')
      expect(tpl.variables[:host_ip]).to eq('10.200.0.42')
    end
  end

  context 'with both global and explicit set (explicit wins)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(consul_dns)) do |node|
        node.automatic[:ipaddress]               = '192.168.1.50'
        node.override[:global][:dns_endpoint_ip] = '10.200.0.42'
        node.override[:consul][:dns][:host_ip]   = '10.200.0.99'
      end.converge('consul::dns')
    end

    it 'prefers the cookbook-namespace explicit override over the global default' do
      tpl = chef_run.template('/etc/dnsmasq.d/consul.conf')
      expect(tpl.variables[:host_ip]).to eq('10.200.0.99')
    end
  end
end
