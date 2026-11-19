# frozen_string_literal: true

# -------------------------------------------------------------------------------
# firecracker integration controls
#
# The thin pool up, containerd's devmapper snapshotter loaded on it, and
# Firecracker's user at its UID.
# -------------------------------------------------------------------------------

control 'host' do
  impact 1.0
  title 'firecracker::host readies the thin pool, containerd and the user'

  describe user('firecracker') do
    it { should exist }
    its('uid') { should eq 990 }
    its('gid') { should eq 990 }
  end

  describe service('containerd-thinpool') do
    it { should be_enabled }
  end

  describe command('dmsetup status containerd-thinpool') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/thin-pool/) }
  end

  # --- "ok" only when the snapshotter found the pool as containerd started. ---
  describe command('ctr plugins ls') do
    its('stdout') { should match(/io\.containerd\.snapshotter\.v1\s+devmapper\s+\S+\s+ok/) }
  end
end
