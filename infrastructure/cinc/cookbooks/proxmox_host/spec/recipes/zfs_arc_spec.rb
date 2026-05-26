# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# zfs_arc recipe spec -- step_into proxmox_host_zfs_arc to cover the
# modprobe.d file + live-cap execute.
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::zfs_arc' do
  context 'with max_bytes set (chef-managed cap)' do
    cached(:chef_run) do
      stub_command('test "$(cat /sys/module/zfs/parameters/zfs_arc_max)" = "34359738368"').and_return(false)
      # --- only_if checks sysfs path presence; pretend the ZFS module is loaded so the live-cap exec is not gated out ---
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/sys/module/zfs/parameters/zfs_arc_max').and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_zfs_arc)) do |node|
        node.normal['proxmox_host']['zfs_arc']['max_bytes'] = 34_359_738_368
      end.converge(described_recipe)
    end

    it 'declares the wrapping proxmox_host_zfs_arc resource' do
      expect(chef_run).to configure_proxmox_host_zfs_arc('zfs_arc')
        .with(max_bytes: 34_359_738_368)
    end

    it 'writes /etc/modprobe.d/zfs.conf root:root 0644 with the cap value' do
      expect(chef_run).to create_file('/etc/modprobe.d/zfs.conf')
        .with(owner: 'root', group: 'root', mode: '0644',
              content: "options zfs zfs_arc_max=34359738368\n")
    end

    it 'declares the live-cap execute (sysfs drift gate)' do
      expect(chef_run).to run_execute('live-cap zfs_arc_max to 34359738368')
    end
  end

  context 'with max_bytes nil (cookbook removes its drop-in)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(proxmox_host_zfs_arc)).converge(described_recipe)
    end

    it 'deletes /etc/modprobe.d/zfs.conf when no cap is requested' do
      expect(chef_run).to delete_file('/etc/modprobe.d/zfs.conf')
    end

    it 'does NOT declare the live-cap execute' do
      expect(chef_run.find_resources(:execute)).to be_empty
    end
  end
end
