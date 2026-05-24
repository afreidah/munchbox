# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec
#
# Covers client mode (oracle-style), server mode (bare-metal), the
# combined server+client mode (single-host dev), and the fail-fast
# guards. vault_fetch is stubbed on both Chef::Recipe and Chef::Resource
# because the consul_token property uses lazy {} which evaluates in the
# resource context.
# -------------------------------------------------------------------------------

RSpec.describe 'nomad::configure' do
  before do
    # --- Stub both contexts; lazy{} evaluates against Chef::Resource ---
    allow_any_instance_of(Chef::Recipe).to receive(:vault_fetch).and_return('test-consul-token')
    allow_any_instance_of(Chef::Resource).to receive(:vault_fetch).and_return('test-consul-token')
  end

  context 'as a client (oracle-style attrs)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(nomad_configure)) do |node|
        node.override[:nomad][:config][:node_name]    = 'oraclearm2'
        node.override[:nomad][:config][:bind_addr]    = '10.200.0.14'
        node.override[:nomad][:config][:advertise_ip] = '10.200.0.14'
        node.override[:nomad][:config][:servers]      = ['192.168.68.60:4647', '192.168.68.61:4647', '192.168.68.58:4647']
        node.override[:nomad][:config][:node_pool]    = 'oracle'
        node.override[:nomad][:config][:client_meta]  = { 'cloud' => 'oracle' }
        node.override[:nomad][:config][:network_interface] = 'wg1'
      end.converge('nomad::configure')
    end

    # --- Resource declaration ---
    it 'declares the nomad_configure resource' do
      expect(chef_run).to configure_nomad_configure('nomad')
    end

    # --- Config template perms (default user=root for parity with ansible-managed state ownership) ---
    it 'renders /etc/nomad.d/nomad.hcl with 0640 root:root' do
      expect(chef_run).to create_template('/etc/nomad.d/nomad.hcl')
        .with(owner: 'root', group: 'root', mode: '0640')
    end

    # --- Per-node attrs propagate ---
    it 'passes node_name, bind_addr, advertise_ip, server_enabled=false through to the template' do
      template = chef_run.template('/etc/nomad.d/nomad.hcl')
      expect(template.variables[:node_name]).to eq('oraclearm2')
      expect(template.variables[:bind_addr]).to eq('10.200.0.14')
      expect(template.variables[:advertise_ip]).to eq('10.200.0.14')
      expect(template.variables[:server_enabled]).to eq(false)
      expect(template.variables[:client_enabled]).to eq(true)
    end

    # --- Oracle-specific fleet attrs propagate ---
    it 'passes oracle node_pool + cloud meta + wg1 interface through to the template' do
      template = chef_run.template('/etc/nomad.d/nomad.hcl')
      expect(template.variables[:node_pool]).to eq('oracle')
      expect(template.variables[:client_meta]['cloud']).to eq('oracle')
      expect(template.variables[:network_interface]).to eq('wg1')
    end

    # --- Systemd unit lifecycle ---
    it 'installs + enables + starts the nomad.service systemd unit' do
      expect(chef_run).to create_systemd_unit('nomad.service')
      expect(chef_run).to enable_systemd_unit('nomad.service')
      expect(chef_run).to start_systemd_unit('nomad.service')
    end

    # --- Restart notification on config drift ---
    it 'restarts nomad.service when nomad.hcl changes (delayed)' do
      expect(chef_run.template('/etc/nomad.d/nomad.hcl'))
        .to notify('systemd_unit[nomad.service]').to(:restart).delayed
    end
  end

  context 'as a server' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(nomad_configure)) do |node|
        node.override[:nomad][:config][:node_name]        = 'goren'
        node.override[:nomad][:config][:bind_addr]        = '192.168.68.60'
        node.override[:nomad][:config][:advertise_ip]     = '192.168.68.60'
        node.override[:nomad][:config][:server_enabled]   = true
        node.override[:nomad][:config][:client_enabled]   = false
        node.override[:nomad][:config][:bootstrap_expect] = 3
        node.override[:nomad][:config][:servers]          = []
      end.converge('nomad::configure')
    end

    # --- Server mode flips ---
    it 'renders the template with server_enabled=true, client_enabled=false, bootstrap_expect=3' do
      template = chef_run.template('/etc/nomad.d/nomad.hcl')
      expect(template.variables[:server_enabled]).to eq(true)
      expect(template.variables[:client_enabled]).to eq(false)
      expect(template.variables[:bootstrap_expect]).to eq(3)
    end
  end

  context 'with server_enabled=true but no bootstrap_expect' do
    # --- Fail-fast: missing bootstrap_expect would let nomad refuse to bootstrap mid-converge ---
    it 'raises an actionable error' do
      runner = ChefSpec::SoloRunner.new(step_into: %w(nomad_configure), log_level: :fatal) do |node|
        node.override[:nomad][:config][:node_name]        = 'goren'
        node.override[:nomad][:config][:bind_addr]        = '192.168.68.60'
        node.override[:nomad][:config][:advertise_ip]     = '192.168.68.60'
        node.override[:nomad][:config][:server_enabled]   = true
        node.override[:nomad][:config][:client_enabled]   = false
        node.override[:nomad][:config][:servers]          = []
      end
      orig_stdout = $stdout
      $stdout = StringIO.new
      begin
        expect { runner.converge('nomad::configure') }
          .to raise_error(/server_enabled=true requires bootstrap_expect/)
      ensure
        $stdout = orig_stdout
      end
    end
  end

  context 'with client_enabled=true but no servers list' do
    # --- Fail-fast: missing servers means client can never join, agent flaps ---
    it 'raises an actionable error' do
      runner = ChefSpec::SoloRunner.new(step_into: %w(nomad_configure), log_level: :fatal) do |node|
        node.override[:nomad][:config][:node_name]    = 'oraclearm2'
        node.override[:nomad][:config][:bind_addr]    = '10.200.0.14'
        node.override[:nomad][:config][:advertise_ip] = '10.200.0.14'
        # servers intentionally left empty
      end
      orig_stdout = $stdout
      $stdout = StringIO.new
      begin
        expect { runner.converge('nomad::configure') }
          .to raise_error(/client_enabled=true requires servers list/)
      ensure
        $stdout = orig_stdout
      end
    end
  end
end
