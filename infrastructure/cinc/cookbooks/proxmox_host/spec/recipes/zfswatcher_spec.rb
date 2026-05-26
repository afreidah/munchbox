# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# zfswatcher recipe spec -- step_into proxmox_host_zfswatcher to cover
# the disabled / enabled paths. vault_fetch (proxy_password_hash) is
# stubbed globally in spec_helper.
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::zfswatcher' do
  context 'with zfswatcher disabled (the default)' do
    cached(:chef_run) do
      stub_command("systemctl list-unit-files | grep -q '^zfswatcher.service'").and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_zfswatcher)).converge(described_recipe)
    end

    it 'declares the wrapping resource with enabled=false' do
      expect(chef_run).to configure_proxmox_host_zfswatcher('zfswatcher').with(enabled: false)
    end

    it 'deletes the config file (cleanup path)' do
      expect(chef_run).to delete_file('/etc/zfswatcher/zfswatcher.conf')
    end

    it 'does not declare any systemd_unit (early-return after cleanup)' do
      expect(chef_run.find_resources(:systemd_unit)).to be_empty
    end
  end

  context 'with zfswatcher enabled' do
    cached(:chef_run) do
      # --- not_if guards on the build resource's git-checkout + initial-build executes ---
      stub_command(/git rev-parse master/).and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_zfswatcher proxmox_host_zfswatcher_build)) do |node|
        node.normal['proxmox_host']['zfswatcher']['enabled'] = true
      end.converge(described_recipe)
    end

    it 'declares the build resource ahead of the daemon (binary is owned by the build resource now)' do
      expect(chef_run).to install_proxmox_host_zfswatcher_build('zfswatcher')
        .with(repo_url: 'https://github.com/rouben/zfswatcher.git', ref: 'master')
    end

    it 'waits for the apt lock before the toolchain install' do
      expect(chef_run).to wait_munchbox_base_apt_lock_wait('proxmox_host_zfswatcher_build_zfswatcher')
    end

    it 'installs the build toolchain (golang, git, build-essential) via apt' do
      expect(chef_run).to install_apt_package(%w(git golang-go build-essential))
    end

    it 'creates the install_dir root:root 0755' do
      expect(chef_run).to create_directory('/opt/zfswatcher')
        .with(owner: 'root', group: 'root', mode: '0755')
    end

    it 'declares the git-clone execute (idempotent on subsequent runs)' do
      expect(chef_run).to run_execute('git clone zfswatcher (master)')
    end

    it 'declares the fetch+checkout execute that notifies the build on ref drift' do
      expect(chef_run).to run_execute('git fetch + checkout zfswatcher master')
      expect(chef_run.execute('git fetch + checkout zfswatcher master'))
        .to notify('execute[go build zfswatcher (master)]').to(:run).immediately
    end

    it 'declares the go-build execute :nothing (only fires on the fetch/checkout notify)' do
      expect(chef_run.execute('go build zfswatcher (master)')).to do_nothing
    end

    it 'declares the initial-build execute gated on binary absence' do
      expect(chef_run).to run_execute('initial build zfswatcher (master)')
    end

    it 'creates the config dir + log dir root:root 0755' do
      expect(chef_run).to create_directory('/etc/zfswatcher')
        .with(owner: 'root', group: 'root', mode: '0755')
      expect(chef_run).to create_directory('/var/log/zfswatcher')
        .with(owner: 'root', group: 'root', mode: '0755')
    end

    it 'renders the zfswatcher.conf template root:root 0640 sensitive with the vault-fetched proxy password' do
      expect(chef_run).to create_template('/etc/zfswatcher/zfswatcher.conf')
        .with(owner: 'root', group: 'root', mode: '0640', sensitive: true)
      vars = chef_run.template('/etc/zfswatcher/zfswatcher.conf').variables
      expect(vars[:bind]).to eq('0.0.0.0:8800')
      expect(vars[:proxy_password_hash]).to eq('fake-vault-value')
    end

    it 'creates + enables + starts the systemd unit' do
      expect(chef_run).to create_systemd_unit('zfswatcher.service')
      expect(chef_run).to enable_systemd_unit('zfswatcher.service')
      expect(chef_run).to start_systemd_unit('zfswatcher.service')
    end

    it 'renders the consul service registration consul:consul 0640' do
      expect(chef_run).to create_template('/etc/consul.d/zfswatcher.json')
        .with(owner: 'consul', group: 'consul', mode: '0640')
      vars = chef_run.template('/etc/consul.d/zfswatcher.json').variables
      expect(vars[:port]).to eq(8800)
      expect(vars[:check_host]).to eq('127.0.0.1')
    end

    it 'notifies consul reload (delayed) on consul-service template change' do
      expect(chef_run.template('/etc/consul.d/zfswatcher.json'))
        .to notify('service[consul]').to(:reload).delayed
    end

    it 'declares the zfswatcher + consul services as :nothing helpers' do
      expect(chef_run.service('zfswatcher')).to do_nothing
      expect(chef_run.service('consul')).to do_nothing
    end
  end
end
