# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# gvt_g recipe spec -- step_into proxmox_host_gvt_g to cover the
# /etc/modules appends. The grub cmdline is owned by kernel_cmdline now.
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::gvt_g' do
  context 'with gvt_g disabled (the default)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_gvt_g)).converge(described_recipe)
    end

    it 'declares the wrapping resource with enabled=false' do
      expect(chef_run).to configure_proxmox_host_gvt_g('gvt_g').with(enabled: false)
    end

    it 'does not declare any execute resources (resource action early-returns)' do
      expect(chef_run.find_resources(:execute)).to be_empty
    end
  end

  context 'with gvt_g enabled' do
    cached(:chef_run) do
      %w(kvmgt vfio-iommu-type1 vfio-mdev).each do |m|
        stub_command("grep -qxE '^#{Regexp.escape(m)}$' /etc/modules").and_return(false)
      end
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_gvt_g)) do |node|
        node.normal['proxmox_host']['gvt_g']['enabled'] = true
      end.converge(described_recipe)
    end

    it 'appends each kernel module to /etc/modules' do
      %w(kvmgt vfio-iommu-type1 vfio-mdev).each do |m|
        expect(chef_run).to run_execute("ensure module #{m} in /etc/modules")
      end
    end

    it 'no longer manages grub (only the module appends remain)' do
      expect(chef_run.find_resources(:execute).map(&:name)).to all(match(/^ensure module/))
    end
  end
end
