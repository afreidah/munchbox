# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# pci_passthrough recipe spec -- step_into proxmox_host_pci_passthrough to
# cover the module appends and the vfio modprobe drop-in. The grub cmdline
# is owned by kernel_cmdline now.
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::pci_passthrough' do
  context 'with pci_passthrough disabled (the default)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_pci_passthrough)).converge(described_recipe)
    end

    it 'declares the wrapping resource with enabled=false' do
      expect(chef_run).to configure_proxmox_host_pci_passthrough('pci_passthrough').with(enabled: false)
    end

    it 'does not declare any execute or file resources (resource action early-returns)' do
      expect(chef_run.find_resources(:execute)).to be_empty
      expect(chef_run.find_resources(:file)).to be_empty
    end
  end

  context 'with pci_passthrough enabled + device_ids set' do
    cached(:chef_run) do
      %w(vfio vfio_iommu_type1 vfio_pci).each do |m|
        stub_command("grep -qxE '^#{Regexp.escape(m)}$' /etc/modules").and_return(false)
      end
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_pci_passthrough)) do |node|
        node.normal['proxmox_host']['pci_passthrough']['enabled'] = true
        node.normal['proxmox_host']['pci_passthrough']['device_ids'] = %w(10de:1c82 10de:0fb9)
      end.converge(described_recipe)
    end

    it 'appends each vfio kernel module to /etc/modules' do
      %w(vfio vfio_iommu_type1 vfio_pci).each do |m|
        expect(chef_run).to run_execute("ensure module #{m} in /etc/modules")
      end
    end

    it 'writes /etc/modprobe.d/vfio.conf with the device IDs comma-joined' do
      expect(chef_run).to create_file('/etc/modprobe.d/vfio.conf')
        .with(owner: 'root', group: 'root', mode: '0644',
              content: "options vfio-pci ids=10de:1c82,10de:0fb9\n")
    end
  end

  context 'with pci_passthrough enabled but no device_ids' do
    cached(:chef_run) do
      %w(vfio vfio_iommu_type1 vfio_pci).each do |m|
        stub_command("grep -qxE '^#{Regexp.escape(m)}$' /etc/modules").and_return(false)
      end
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_pci_passthrough)) do |node|
        node.normal['proxmox_host']['pci_passthrough']['enabled'] = true
      end.converge(described_recipe)
    end

    it 'skips the vfio modprobe drop-in when device_ids is empty' do
      expect(chef_run.find_resources(:file).map(&:name)).not_to include('/etc/modprobe.d/vfio.conf')
    end
  end
end
