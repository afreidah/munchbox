# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# ksm recipe spec -- step_into proxmox_host_ksm to cover the ksmtuned
# package + service in both the enabled and disabled paths.
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::ksm' do
  context 'enabled (default)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_ksm)).converge(described_recipe)
    end

    it 'installs PVE ksm-control-daemon (not the conflicting debian ksmtuned)' do
      expect(chef_run).to install_package('ksm-control-daemon')
    end

    it 'enables and starts the ksmtuned service' do
      expect(chef_run).to enable_service('ksmtuned')
      expect(chef_run).to start_service('ksmtuned')
    end
  end

  context 'disabled' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_ksm)) do |node|
        node.normal['proxmox_host']['ksm']['enabled'] = false
      end.converge(described_recipe)
    end

    it 'stops and disables ksmtuned without removing the package' do
      expect(chef_run).to stop_service('ksmtuned')
      expect(chef_run).to disable_service('ksmtuned')
      expect(chef_run).to_not install_package('ksm-control-daemon')
    end
  end
end
