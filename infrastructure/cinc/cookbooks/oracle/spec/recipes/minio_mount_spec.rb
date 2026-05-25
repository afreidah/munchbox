# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# minio_mount recipe spec -- steps into oracle_minio_mount to cover the
# blkid lookup, legacy /dev/sdb cleanup, and the UUID mount. shell_out is
# stubbed per-provider via chefspec's stubs_for_provider helper.
# -------------------------------------------------------------------------------

RSpec.describe 'oracle::minio_mount' do
  context 'with a labeled volume present' do
    cached(:chef_run) do
      stubs_for_provider('oracle_minio_mount[/mnt/minio-data]') do |provider|
        allow(provider).to receive_shell_out(
          'blkid', '-t', 'LABEL=minio-data', '-o', 'value', '-s', 'UUID',
          stdout: "9c4a5d6e-1111-2222-3333-444455556666\n"
        )
      end
      allow(::File).to receive(:read).and_call_original
      allow(::File).to receive(:read).with('/etc/fstab')
                                     .and_return("/dev/sdb /mnt/minio-data ext4 defaults 0 2\n")
      ChefSpec::SoloRunner.new(step_into: %w(oracle_minio_mount)).converge('oracle::minio_mount')
    end

    it 'declares the oracle_minio_mount wrapping resource' do
      expect(chef_run).to mount_oracle_minio_mount('/mnt/minio-data')
        .with(label: 'minio-data', fstype: 'ext4')
    end

    it 'creates the mount point' do
      expect(chef_run).to create_directory('/mnt/minio-data')
        .with(owner: 'root', group: 'root', mode: '0755')
    end

    it 'enables the UUID-based mount in fstab' do
      expect(chef_run).to enable_mount('/mnt/minio-data')
        .with(device: '9c4a5d6e-1111-2222-3333-444455556666',
              device_type: :uuid,
              fstype: 'ext4',
              options: %w(defaults nofail _netdev))
    end

    it 'mounts the volume' do
      expect(chef_run).to mount_mount('/mnt/minio-data')
        .with(device: '9c4a5d6e-1111-2222-3333-444455556666')
    end

    it 'disables the legacy /dev/sdb fstab entry (only_if fstab regex matches)' do
      expect(chef_run).to disable_mount('remove legacy /dev/sdb entry at /mnt/minio-data')
    end
  end

  context 'with no labeled volume found (resource action is a no-op past the mount point)' do
    cached(:chef_run) do
      stubs_for_provider('oracle_minio_mount[/mnt/minio-data]') do |provider|
        allow(provider).to receive_shell_out(
          'blkid', '-t', 'LABEL=minio-data', '-o', 'value', '-s', 'UUID',
          stdout: "\n"
        )
      end
      ChefSpec::SoloRunner.new(step_into: %w(oracle_minio_mount)).converge('oracle::minio_mount')
    end

    it 'creates the mount point' do
      expect(chef_run).to create_directory('/mnt/minio-data')
    end

    it 'does NOT enable any mount when UUID lookup is empty' do
      expect(chef_run.find_resource(:mount, '/mnt/minio-data')).to be_nil
    end
  end
end
