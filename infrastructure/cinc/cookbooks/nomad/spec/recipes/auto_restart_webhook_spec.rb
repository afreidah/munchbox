# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# auto_restart_webhook recipe spec -- steps into nomad_auto_restart_webhook so
# the file/template/systemd_unit/service resources it declares are covered.
# vault_fetch is stubbed globally in spec_helper. The `enabled` attribute picks
# the action, so both the :configure and :remove paths are converged here.
# -------------------------------------------------------------------------------

RSpec.describe 'nomad::auto_restart_webhook' do
  # --- enabled defaults false; the configure path needs it flipped on ---
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(nomad_auto_restart_webhook)) do |node|
      node.normal['nomad']['auto_restart_webhook']['enabled'] = true
    end.converge(described_recipe)
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

  # --- the resource raises "nomad_token cannot be empty" when vault_fetch returns
  #     empty; we don't exercise that here because chef's compile-error formatter
  #     writes the banner directly to STDOUT (not $stdout / Chef::Log), which
  #     can't be silenced inside an rspec expect block. The defensive raise is
  #     covered live: a node where vault returns no token fails its converge with
  #     the helpful message.

  context 'with stale_paths configured' do
    cached(:sweep_run) do
      ChefSpec::SoloRunner.new(step_into: %w(nomad_auto_restart_webhook)) do |node|
        node.normal['nomad']['auto_restart_webhook']['enabled'] = true
        node.normal['nomad']['auto_restart_webhook']['stale_paths'] = ['/usr/local/bin/nomad-auto-restart.sh']
      end.converge(described_recipe)
    end

    it 'sweeps each stale path' do
      expect(sweep_run).to delete_file('/usr/local/bin/nomad-auto-restart.sh')
    end
  end

  # -------------------------------------------------------------------------------
  # Disabled -- the recipe dispatches :remove and the resource tears everything down
  # -------------------------------------------------------------------------------

  context 'when enabled is false' do
    cached(:removed_run) do
      # --- only_if shell guard on the stop; stub positive so the action fires ---
      stub_command("systemctl list-unit-files | grep -q '^nomad-auto-restart-webhook.service'").and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(nomad_auto_restart_webhook)).converge(described_recipe)
    end

    it 'dispatches :remove instead of :configure' do
      expect(removed_run).to remove_nomad_auto_restart_webhook('baseline')
    end

    it 'stops + disables the service before the unit file is deleted' do
      expect(removed_run).to stop_service('nomad-auto-restart-webhook')
      expect(removed_run).to disable_service('nomad-auto-restart-webhook')
    end

    it 'deletes the systemd unit' do
      expect(removed_run).to delete_systemd_unit('nomad-auto-restart-webhook.service')
    end

    it 'deletes the script, log and consul registration' do
      expect(removed_run).to delete_file('/usr/local/bin/nomad-auto-restart-webhook.py')
      expect(removed_run).to delete_file('/var/log/nomad-auto-restart.log')
      expect(removed_run).to delete_file('/etc/consul.d/nomad-auto-restart-webhook.json')
    end

    it 'deletes the cooldown dir recursively' do
      expect(removed_run).to delete_directory('/tmp/nomad-restart-cooldown')
      expect(removed_run.directory('/tmp/nomad-restart-cooldown').recursive).to be true
    end

    it 'notifies consul to reload (delayed) when the registration is removed' do
      expect(removed_run.file('/etc/consul.d/nomad-auto-restart-webhook.json'))
        .to notify('service[consul]').to(:reload).delayed
    end

    it 'renders nothing from the configure path' do
      expect(removed_run).to_not create_template('/usr/local/bin/nomad-auto-restart-webhook.py')
      expect(removed_run).to_not create_systemd_unit('nomad-auto-restart-webhook.service')
      expect(removed_run).to_not start_service('nomad-auto-restart-webhook')
    end

    # --- nomad_token is required: [:configure], so the lazy vault_fetch never
    #     evaluates here. Re-stub it to raise: a disabled node must converge
    #     even once its vault path is gone.
    it 'never reads the vault-backed nomad_token' do
      MunchboxLibVaultFetch.module_eval do
        define_method(:vault_fetch) { |_path, _field| raise 'vault_fetch called on a disabled node' }
      end
      stub_command("systemctl list-unit-files | grep -q '^nomad-auto-restart-webhook.service'").and_return(true)

      expect do
        ChefSpec::SoloRunner.new(step_into: %w(nomad_auto_restart_webhook)).converge(described_recipe)
      end.to_not raise_error
    end
  end
end
