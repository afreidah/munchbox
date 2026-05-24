# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec
#
# Covers client mode (oracle-style, the common case), server mode
# (bare-metal goren/stabler), and the fail-fast guards around
# server/bootstrap_expect + ACL token presence. vault_fetch is stubbed --
# specs never try to read /run/vault-agent/token.
# -------------------------------------------------------------------------------

RSpec.describe 'consul::configure' do
  before do
    # --- Stub both contexts; lazy{} on the property evaluates against Chef::Resource. ---
    allow_any_instance_of(Chef::Recipe).to receive(:vault_fetch).and_return('test-acl-agent-token')
    allow_any_instance_of(Chef::Resource).to receive(:vault_fetch).and_return('test-acl-agent-token')
  end

  context 'as a client (default mode, with required per-node overrides)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(consul_configure)) do |node|
        node.override[:consul][:config][:bind_addr]  = '10.200.0.14'
        node.override[:consul][:config][:retry_join] = ['192.168.68.60', '192.168.68.61', '192.168.68.58']
      end.converge('consul::configure')
    end

    # --- Resource declaration ---
    it 'declares the consul_configure resource' do
      expect(chef_run).to configure_consul_configure('consul')
    end

    # --- Config template perms + sensitivity ---
    it 'renders /etc/consul.d/consul.hcl with 0640 consul:consul' do
      expect(chef_run).to create_template('/etc/consul.d/consul.hcl')
        .with(owner: 'consul', group: 'consul', mode: '0640')
    end

    # --- Per-node bind_addr + retry_join propagate to the template ---
    it 'passes the per-node bind_addr + retry_join + server=false through to the template' do
      template = chef_run.template('/etc/consul.d/consul.hcl')
      expect(template.variables[:bind_addr]).to eq('10.200.0.14')
      expect(template.variables[:server]).to eq(false)
      expect(template.variables[:retry_join]).to include('192.168.68.60')
    end

    # --- ACL token comes from vault_fetch (stubbed) and lands in template vars ---
    it 'passes the vault-fetched ACL agent token through to the template' do
      template = chef_run.template('/etc/consul.d/consul.hcl')
      expect(template.variables[:acl_agent_token]).to eq('test-acl-agent-token')
    end

    # --- Systemd unit lifecycle ---
    it 'installs + enables + starts the consul.service systemd unit' do
      expect(chef_run).to create_systemd_unit('consul.service')
      expect(chef_run).to enable_systemd_unit('consul.service')
      expect(chef_run).to start_systemd_unit('consul.service')
    end

    # --- Restart notification on config drift ---
    it 'restarts consul.service when consul.hcl changes (delayed)' do
      expect(chef_run.template('/etc/consul.d/consul.hcl'))
        .to notify('systemd_unit[consul.service]').to(:restart).delayed
    end
  end

  context 'as a server' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(consul_configure)) do |node|
        node.override[:consul][:config][:bind_addr]        = '192.168.68.60'
        node.override[:consul][:config][:retry_join]       = ['192.168.68.60', '192.168.68.61', '192.168.68.58']
        node.override[:consul][:config][:server]           = true
        node.override[:consul][:config][:bootstrap_expect] = 3
      end.converge('consul::configure')
    end

    # --- Server mode flips server + bootstrap_expect into the template ---
    it 'renders the template with server=true + bootstrap_expect' do
      template = chef_run.template('/etc/consul.d/consul.hcl')
      expect(template.variables[:server]).to eq(true)
      expect(template.variables[:bootstrap_expect]).to eq(3)
    end
  end

  context 'with server=true but no bootstrap_expect' do
    # --- Fail-fast: missing bootstrap_expect would otherwise let consul refuse to start mid-converge ---
    it 'raises an actionable error' do
      runner = ChefSpec::SoloRunner.new(step_into: %w(consul_configure), log_level: :fatal) do |node|
        node.override[:consul][:config][:bind_addr]  = '192.168.68.60'
        node.override[:consul][:config][:retry_join] = ['192.168.68.60']
        node.override[:consul][:config][:server]     = true
      end
      orig_stdout = $stdout
      $stdout = StringIO.new
      begin
        expect { runner.converge('consul::configure') }
          .to raise_error(/server=true requires bootstrap_expect/)
      ensure
        $stdout = orig_stdout
      end
    end
  end
end
