# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# client recipe spec -- steps into nfs_mount to cover the directory + mount
# resources it declares.
# -------------------------------------------------------------------------------

RSpec.describe 'nfs::client' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(nfs_mount)).converge(described_recipe)
  end

  it 'installs nfs-common' do
    expect(chef_run).to install_apt_package('nfs-common')
  end

  it 'declares no nfs_mount resources when mounts is empty (the default)' do
    expect(chef_run.find_resources(:nfs_mount)).to be_empty
  end

  context 'with a shared mount declared via attributes' do
    cached(:with_mount_run) do
      allow(::File).to receive(:directory?).and_call_original
      allow(::File).to receive(:directory?).with('/mnt/gdrive').and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(nfs_mount)) do |node|
        node.normal['nfs']['client']['mounts'] = [
          { 'mount_point' => '/mnt/gdrive', 'device' => 'mccoy:/mnt/gdrive' },
        ]
      end.converge(described_recipe)
    end

    it 'declares the nfs_mount keyed by mount_point' do
      expect(with_mount_run).to create_nfs_mount('/mnt/gdrive')
        .with(device: 'mccoy:/mnt/gdrive')
    end

    it 'creates the mount-point directory root:root 0755 (recursive)' do
      expect(with_mount_run).to create_directory('/mnt/gdrive')
        .with(owner: 'root', group: 'root', mode: '0755', recursive: true)
    end

    it 'mounts and enables the export in fstab' do
      # --- chef splits the comma-joined options string into an array at parse time ---
      expect(with_mount_run).to mount_mount('/mnt/gdrive')
        .with(device: 'mccoy:/mnt/gdrive', fstype: 'nfs', options: %w(defaults _netdev))
      expect(with_mount_run).to enable_mount('/mnt/gdrive')
    end
  end

  context 'with both mounts + extra_mounts populated' do
    cached(:two_mounts_run) do
      allow(::File).to receive(:directory?).and_call_original
      allow(::File).to receive(:directory?).with('/mnt/shared').and_return(false)
      allow(::File).to receive(:directory?).with('/mnt/node-only').and_return(false)
      ChefSpec::SoloRunner.new(step_into: %w(nfs_mount)) do |node|
        node.normal['nfs']['client']['mounts'] = [
          { 'mount_point' => '/mnt/shared', 'device' => 'mccoy:/mnt/shared' },
        ]
        node.normal['nfs']['client']['extra_mounts'] = [
          { 'mount_point' => '/mnt/node-only', 'device' => 'mccoy:/mnt/node-only',
            'fstype' => 'nfs4', 'options' => 'rw,vers=4' },
        ]
      end.converge(described_recipe)
    end

    it 'materializes both lists' do
      expect(two_mounts_run).to create_nfs_mount('/mnt/shared')
      expect(two_mounts_run).to create_nfs_mount('/mnt/node-only')
        .with(fstype: 'nfs4', options: 'rw,vers=4')
    end

    it 'creates the mount-point directories for both' do
      expect(two_mounts_run).to create_directory('/mnt/shared')
      expect(two_mounts_run).to create_directory('/mnt/node-only')
    end

    it 'mounts both with their respective fstype/options' do
      expect(two_mounts_run).to mount_mount('/mnt/shared')
        .with(fstype: 'nfs')
      expect(two_mounts_run).to mount_mount('/mnt/node-only')
        .with(fstype: 'nfs4', options: %w(rw vers=4))
    end
  end
end
