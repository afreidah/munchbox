# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# kernel_cmdline recipe spec -- step_into proxmox_host_kernel_cmdline to
# cover the composed GRUB_CMDLINE_LINUX_DEFAULT for each flag combination.
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::kernel_cmdline' do
  def cmdline(chef_run)
    chef_run.execute('update GRUB_CMDLINE_LINUX_DEFAULT').command
  end

  context 'base only (no gpu, no mitigations)' do
    cached(:chef_run) do
      stub_command(/grep -qxF/).and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_kernel_cmdline)).converge(described_recipe)
    end

    it 'sets the cmdline to just the base' do
      expect(cmdline(chef_run)).to include('GRUB_CMDLINE_LINUX_DEFAULT="quiet"')
    end

    it 'declares the kernel_cmdline resource and runs the grub sed (not_if stubbed false)' do
      expect(chef_run).to configure_proxmox_host_kernel_cmdline('grub')
      expect(chef_run).to run_execute('update GRUB_CMDLINE_LINUX_DEFAULT')
      expect(chef_run.execute('update-grub')).to do_nothing
    end
  end

  context 'gvt_g enabled' do
    cached(:chef_run) do
      stub_command(/grep -qxF/).and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_kernel_cmdline)) do |node|
        node.normal['proxmox_host']['gvt_g']['enabled'] = true
      end.converge(described_recipe)
    end

    it 'adds the gvt-g iommu params' do
      expect(cmdline(chef_run)).to include('GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on i915.enable_gvt=1"')
    end
  end

  context 'pci_passthrough enabled' do
    cached(:chef_run) do
      stub_command(/grep -qxF/).and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_kernel_cmdline)) do |node|
        node.normal['proxmox_host']['pci_passthrough']['enabled'] = true
      end.converge(described_recipe)
    end

    it 'adds the passthrough iommu params' do
      expect(cmdline(chef_run)).to include('GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"')
    end
  end

  context 'mitigations_off' do
    cached(:chef_run) do
      stub_command(/grep -qxF/).and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_kernel_cmdline)) do |node|
        node.normal['proxmox_host']['kernel_cmdline']['mitigations_off'] = true
      end.converge(described_recipe)
    end

    it 'appends mitigations=off to the base' do
      expect(cmdline(chef_run)).to include('GRUB_CMDLINE_LINUX_DEFAULT="quiet mitigations=off"')
    end

    it 'notifies update-grub immediately on change' do
      expect(chef_run.execute('update GRUB_CMDLINE_LINUX_DEFAULT'))
        .to notify('execute[update-grub]').to(:run).immediately
    end
  end
end
