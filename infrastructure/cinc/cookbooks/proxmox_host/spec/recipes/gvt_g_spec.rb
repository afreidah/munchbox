# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# gvt_g recipe spec -- step_into proxmox_host_gvt_g to cover the GRUB
# rewrite + update-grub + /etc/modules appends.
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
      grub_line = 'GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on i915.enable_gvt=1"'
      stub_command("grep -qxF '#{grub_line}' /etc/default/grub").and_return(false)
      %w(kvmgt vfio-iommu-type1 vfio-mdev).each do |m|
        stub_command("grep -qxE '^#{Regexp.escape(m)}$' /etc/modules").and_return(false)
      end
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_gvt_g)) do |node|
        node.normal['proxmox_host']['gvt_g']['enabled'] = true
      end.converge(described_recipe)
    end

    it 'declares the grub-cmdline rewrite execute' do
      expect(chef_run).to run_execute('update GRUB_CMDLINE_LINUX_DEFAULT (gvt_g)')
    end

    it 'notifies update-grub (immediate) when the grub line changes' do
      expect(chef_run.execute('update GRUB_CMDLINE_LINUX_DEFAULT (gvt_g)'))
        .to notify('execute[update-grub (gvt_g)]').to(:run).immediately
    end

    it 'declares the update-grub execute :nothing' do
      expect(chef_run.execute('update-grub (gvt_g)')).to do_nothing
    end

    it 'appends each kernel module to /etc/modules' do
      %w(kvmgt vfio-iommu-type1 vfio-mdev).each do |m|
        expect(chef_run).to run_execute("ensure module #{m} in /etc/modules")
      end
    end
  end
end
