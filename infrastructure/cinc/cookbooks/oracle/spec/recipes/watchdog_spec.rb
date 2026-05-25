# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# watchdog recipe spec
#
# Covers apt install, config dir + (empty) config.yaml, systemd
# drop-in override, consul service-registration JSON, and the
# enable+start of oracle-watchdog. vault_fetch is stubbed (lazy{}
# evaluates in the resource context).
# -------------------------------------------------------------------------------

RSpec.describe 'oracle::watchdog' do
  # vault_fetch is stubbed globally in spec_helper via MunchboxLibVaultFetch module_eval.

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(oracle_watchdog)).converge('oracle::watchdog')
  end

  it 'declares the oracle_watchdog wrapping resource' do
    expect(chef_run).to configure_oracle_watchdog('baseline')
  end

  # --- Package install (apt repo registered by munchbox_base::apt_repo elsewhere in the run_list) ---
  it 'upgrades the oracle-watchdog apt package' do
    expect(chef_run).to upgrade_apt_package('oracle-watchdog')
  end

  it 'waits for the apt lock before installing oracle-watchdog' do
    expect(chef_run).to wait_munchbox_base_apt_lock_wait('oracle_watchdog_install_baseline')
  end

  # --- Config dir ---
  it 'creates /etc/oracle-watchdog with 0755 root:root' do
    expect(chef_run).to create_directory('/etc/oracle-watchdog')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  # --- Empty-but-present config.yaml ---
  it 'renders /etc/oracle-watchdog/config.yaml with 0644 root:root' do
    expect(chef_run).to create_template('/etc/oracle-watchdog/config.yaml')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  # --- Systemd drop-in dir ---
  it 'creates /etc/systemd/system/oracle-watchdog.service.d with 0755 root:root' do
    expect(chef_run).to create_directory('/etc/systemd/system/oracle-watchdog.service.d')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  # --- Override file with the env vars (sensitive because the token is in it) ---
  it 'renders the systemd override with 0600 root:root and sensitive=true' do
    expect(chef_run).to create_template('/etc/systemd/system/oracle-watchdog.service.d/override.conf')
      .with(owner: 'root', group: 'root', mode: '0600', sensitive: true)
  end

  # --- daemon-reload + watchdog restart fire when the override changes ---
  it 'notifies daemon-reload (immediate) + oracle-watchdog restart (delayed) on override change' do
    template = chef_run.template('/etc/systemd/system/oracle-watchdog.service.d/override.conf')
    expect(template).to notify('execute[oracle_watchdog daemon-reload]').to(:run).immediately
    expect(template).to notify('service[oracle-watchdog]').to(:restart).delayed
  end

  # --- Daemon-reload is declared :nothing so it only runs when notified ---
  it 'declares oracle_watchdog daemon-reload as :nothing' do
    expect(chef_run.execute('oracle_watchdog daemon-reload')).to do_nothing
  end

  # --- Consul service registration; consul user/group exist on oracle nodes already (consul cookbook ran first) ---
  it 'drops /etc/consul.d/oracle-watchdog.json with 0640 consul:consul' do
    expect(chef_run).to create_template('/etc/consul.d/oracle-watchdog.json')
      .with(owner: 'consul', group: 'consul', mode: '0640')
  end

  # --- Service-registration JSON triggers a consul reload (delayed) ---
  it 'notifies consul reload (delayed) when the service file changes' do
    expect(chef_run.template('/etc/consul.d/oracle-watchdog.json'))
      .to notify('service[consul]').to(:reload).delayed
  end

  # --- oracle-watchdog enabled + running ---
  it 'enables + starts the oracle-watchdog systemd service' do
    expect(chef_run).to enable_service('oracle-watchdog')
    expect(chef_run).to start_service('oracle-watchdog')
  end

  # --- Helper service declared :nothing (only fires when the template notifies a reload) ---
  it 'declares the consul service as :nothing (the consul cookbook owns its lifecycle)' do
    expect(chef_run.service('consul')).to do_nothing
  end
end
