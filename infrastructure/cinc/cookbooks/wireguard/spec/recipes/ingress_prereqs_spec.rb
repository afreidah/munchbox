# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# ingress_prereqs recipe spec -- steps into wireguard_ingress_prereqs to
# cover the modules-load drop-in, modprobe execute, package install, and
# the sysctl-sweep + reload chain.
# -------------------------------------------------------------------------------

RSpec.describe 'wireguard::ingress_prereqs' do
  cached(:chef_run) do
    # --- modprobe guard is shelled out; stub so chefspec doesn't actually exec lsmod ---
    stub_command('lsmod | grep -q "^wireguard "').and_return(false)
    ChefSpec::SoloRunner.new(step_into: %w(wireguard_ingress_prereqs)).converge(described_recipe)
  end

  it 'declares the wireguard_ingress_prereqs resource' do
    expect(chef_run).to configure_wireguard_ingress_prereqs('baseline')
  end

  it 'drops the modules-load.d entry so systemd loads wireguard at boot' do
    expect(chef_run).to create_file('/etc/modules-load.d/wireguard.conf')
      .with(owner: 'root', group: 'root', mode: '0644', content: "wireguard\n")
  end

  it 'modprobes wireguard immediately (guarded by lsmod)' do
    expect(chef_run).to run_execute('modprobe wireguard')
  end

  it 'installs wireguard-tools for operator wg show access' do
    expect(chef_run).to install_package('baseline')
      .with(package_name: %w(wireguard-tools))
  end

  it 'sweeps the obsolete keepalived-vmac sysctl drop-in' do
    expect(chef_run).to delete_file('/etc/sysctl.d/99-keepalived-vmac.conf')
  end

  it 'notifies sysctl --system immediately when a stale sysctl is removed' do
    expect(chef_run.file('/etc/sysctl.d/99-keepalived-vmac.conf'))
      .to notify('execute[wireguard ingress sysctl reload]').to(:run).immediately
  end

  it 'declares the sysctl reload execute (:nothing; only fires on notify)' do
    expect(chef_run.execute('wireguard ingress sysctl reload')).to do_nothing
  end

  context 'when wireguard kernel module is already loaded' do
    cached(:already_loaded_run) do
      stub_command('lsmod | grep -q "^wireguard "').and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(wireguard_ingress_prereqs)).converge(described_recipe)
    end

    it 'skips modprobe' do
      expect(already_loaded_run.execute('modprobe wireguard')).to do_nothing
    end
  end
end
