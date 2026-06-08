# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# apt_repo recipe spec -- step_into proxmox_host_apt_repo to cover the
# authoritative source file (codename from node['os_release'], injected
# here since fauxhai omits it) and the apt update notify.
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::apt_repo' do
  context 'managed (default)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_apt_repo)) do |node|
        node.automatic['os_release']['version_codename'] = 'trixie'
      end.converge(described_recipe)
    end

    it 'writes the pve-no-subscription source with the host codename' do
      expect(chef_run).to create_file('/etc/apt/sources.list.d/pve-no-subscription.list')
        .with(owner: 'root', group: 'root', mode: '0644',
              content: "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription\n")
    end

    it 'notifies apt update when the source changes' do
      expect(chef_run.file('/etc/apt/sources.list.d/pve-no-subscription.list'))
        .to notify('apt_update[pve-no-subscription-changed]').to(:update).delayed
    end
  end

  context 'unmanaged' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_apt_repo)) do |node|
        node.normal['proxmox_host']['apt_repo']['manage'] = false
      end.converge(described_recipe)
    end

    it 'does not touch the source file' do
      expect(chef_run).to_not create_file('/etc/apt/sources.list.d/pve-no-subscription.list')
    end
  end
end
