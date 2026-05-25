# frozen_string_literal: true

# -------------------------------------------------------------------------------
# nfs::server integration controls.
# -------------------------------------------------------------------------------

control 'nfs-kernel-server-installed' do
  impact 1.0
  title 'nfs-kernel-server package is installed'

  describe package('nfs-kernel-server') do
    it { should be_installed }
  end
end

control 'exports-rendered' do
  impact 1.0
  title '/etc/exports has the managed-block header + sample export'

  describe file('/etc/exports') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0644' }
    its('content') { should match(/managed by chef/) }
    its('content') { should include('/srv/nfs/test 127.0.0.0/8(rw,sync,no_subtree_check,no_root_squash)') }
  end
end

control 'nfs-server-service' do
  impact 1.0
  title 'nfs-server systemd unit is enabled + running'

  describe service('nfs-server') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end
