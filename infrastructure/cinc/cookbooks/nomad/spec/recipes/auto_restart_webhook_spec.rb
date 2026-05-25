# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# auto_restart_webhook recipe spec -- steps into nomad_auto_restart_webhook so
# the file/template/systemd_unit/service resources it declares are covered.
# vault_fetch is stubbed globally in spec_helper.
# -------------------------------------------------------------------------------

RSpec.describe 'nomad::auto_restart_webhook' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(nomad_auto_restart_webhook)).converge(described_recipe)
  end

  it 'declares the wrapping resource' do
    expect(chef_run).to configure_nomad_auto_restart_webhook('baseline')
      .with(
        service_name: 'nomad-auto-restart-webhook',
        port: 9095,
        user: 'root',
        group: 'root'
      )
  end

  it 'renders the webhook python script with the configured port + paths' do
    expect(chef_run).to create_template('/usr/local/bin/nomad-auto-restart-webhook.py')
      .with(owner: 'root', group: 'root', mode: '0755')
    tpl = chef_run.template('/usr/local/bin/nomad-auto-restart-webhook.py')
    expect(tpl.variables[:port]).to eq(9095)
    expect(tpl.variables[:bind_address]).to eq('0.0.0.0')
    expect(tpl.variables[:cooldown_seconds]).to eq(300)
    expect(tpl.variables[:cooldown_dir]).to eq('/tmp/nomad-restart-cooldown')
    expect(tpl.variables[:log_file]).to eq('/var/log/nomad-auto-restart.log')
  end

  it 'creates + enables + starts the systemd unit with NOMAD_TOKEN from vault' do
    expect(chef_run).to create_systemd_unit('nomad-auto-restart-webhook.service')
    expect(chef_run).to enable_systemd_unit('nomad-auto-restart-webhook.service')
    expect(chef_run).to start_systemd_unit('nomad-auto-restart-webhook.service')
    unit = chef_run.systemd_unit('nomad-auto-restart-webhook.service')
    expect(unit.content).to include('Environment=NOMAD_TOKEN=fake-vault-value')
    expect(unit.content).to include('ExecStart=/usr/bin/python3 /usr/local/bin/nomad-auto-restart-webhook.py')
  end

  it 'renders the consul-service JSON consul:consul 0640 with the same port the script binds' do
    expect(chef_run).to create_template('/etc/consul.d/nomad-auto-restart-webhook.json')
      .with(owner: 'consul', group: 'consul', mode: '0640')
    tpl = chef_run.template('/etc/consul.d/nomad-auto-restart-webhook.json')
    expect(tpl.variables[:service_name]).to eq('nomad-auto-restart-webhook')
    expect(tpl.variables[:port]).to eq(9095)
    expect(tpl.variables[:check_path]).to eq('/')
  end

  it 'notifies consul to reload (delayed) when the consul-service template changes' do
    expect(chef_run.template('/etc/consul.d/nomad-auto-restart-webhook.json'))
      .to notify('service[consul]').to(:reload).delayed
  end

  it 'enables + starts the webhook service' do
    expect(chef_run).to enable_service('nomad-auto-restart-webhook')
    expect(chef_run).to start_service('nomad-auto-restart-webhook')
  end

  it 'declares consul service with :nothing so notify hooks resolve' do
    expect(chef_run.service('consul')).to do_nothing
  end

  it 'sweeps the default ansible-era webhook .sh leftover' do
    expect(chef_run).to delete_file('/usr/local/bin/nomad-auto-restart-webhook.sh')
  end

  context 'when nomad_token is empty' do
    before do
      MunchboxLibVaultFetch.module_eval do
        define_method(:vault_fetch) { |_path, _field| '' }
      end
    end

    it 'raises rather than rendering an unauthenticated systemd unit' do
      expect do
        ChefSpec::SoloRunner.new(step_into: %w(nomad_auto_restart_webhook)).converge(described_recipe)
      end.to raise_error(/nomad_token cannot be empty/)
    end
  end

  context 'with stale_paths configured' do
    cached(:sweep_run) do
      ChefSpec::SoloRunner.new(step_into: %w(nomad_auto_restart_webhook)) do |node|
        node.normal['nomad']['auto_restart_webhook']['stale_paths'] = ['/usr/local/bin/nomad-auto-restart.sh']
      end.converge(described_recipe)
    end

    it 'sweeps each stale path' do
      expect(sweep_run).to delete_file('/usr/local/bin/nomad-auto-restart.sh')
    end
  end
end
