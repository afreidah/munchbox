# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# minio_mount recipe spec
#
# Covers: blkid UUID lookup, the legacy /dev/sdb fstab cleanup, and the
# UUID-based mount. blkid is stubbed (chefspec doesn't shell out).
# -------------------------------------------------------------------------------

RSpec.describe 'oracle::minio_mount' do
  # --- Fake shell_out for the blkid lookup; we test both the "found" + "missing" paths ---
  let(:blkid_result) do
    instance_double('Mixlib::ShellOut', stdout: "9c4a5d6e-1111-2222-3333-444455556666\n")
  end

  context 'with a labeled volume present' do
    cached(:chef_run) do
      runner_blkid = instance_double('Mixlib::ShellOut', stdout: "9c4a5d6e-1111-2222-3333-444455556666\n")
      allow_any_instance_of(Chef::Recipe).to receive(:shell_out).and_return(runner_blkid)
      ChefSpec::SoloRunner.new.converge('oracle::minio_mount')
    end

    # --- Mount point directory ---
    it 'creates the mount point' do
      expect(chef_run).to create_directory('/mnt/minio-data')
        .with(owner: 'root', group: 'root', mode: '0755')
    end

    # --- UUID-based mount lands in fstab + mounted ---
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

    # --- Legacy /dev/sdb entry is only touched if the fstab regex matches; in chefspec File.read is real, so a synthetic fstab keeps this check trivial ---
    it 'declares the legacy fstab cleanup' do
      expect(chef_run.mount('remove legacy /dev/sdb entry at /mnt/minio-data')).to_not be_nil
    end
  end

  context 'with no labeled volume found (recipe is a no-op)' do
    cached(:chef_run) do
      empty_blkid = instance_double('Mixlib::ShellOut', stdout: "\n")
      allow_any_instance_of(Chef::Recipe).to receive(:shell_out).and_return(empty_blkid)
      ChefSpec::SoloRunner.new.converge('oracle::minio_mount')
    end

    it 'creates the mount point' do
      expect(chef_run).to create_directory('/mnt/minio-data')
    end

    it 'does NOT enable any mount when UUID lookup is empty' do
      expect(chef_run.find_resource(:mount, '/mnt/minio-data')).to be_nil
    end
  end
end
