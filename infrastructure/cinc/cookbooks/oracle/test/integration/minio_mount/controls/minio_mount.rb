# frozen_string_literal: true

# -------------------------------------------------------------------------------
# oracle::minio_mount integration controls.
# -------------------------------------------------------------------------------

control 'mount-point-dir' do
  impact 1.0
  title '/mnt/minio-data exists root:root 0755 even without a labeled block volume'

  describe directory('/mnt/minio-data') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755' }
  end
end

control 'legacy-sdb-fstab-removed' do
  impact 1.0
  title 'pre-staged /dev/sdb /mnt/minio-data line is gone from /etc/fstab after converge'

  describe file('/etc/fstab') do
    its('content') { should_not match(%r{^/dev/sdb\s+/mnt/minio-data\s}) }
  end
end

control 'no-uuid-mount-without-labeled-volume' do
  impact 1.0
  title 'no UUID-based mount line is added because blkid can not find a minio-data labeled volume in kitchen'

  describe file('/etc/fstab') do
    its('content') { should_not match(%r{^UUID=\S+\s+/mnt/minio-data}) }
  end
end
