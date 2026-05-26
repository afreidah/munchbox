# frozen_string_literal: true

# -------------------------------------------------------------------------------
# proxmox_host::zfswatcher integration controls.
# -------------------------------------------------------------------------------

control 'zfswatcher-build-toolchain' do
  impact 1.0
  title 'go toolchain + git + build-essential are installed'

  %w(golang-go git build-essential).each do |pkg|
    describe package(pkg) do
      it { should be_installed }
    end
  end
end

control 'zfswatcher-binary' do
  impact 1.0
  title 'binary built from source is on disk + executable + version-stamped'

  describe file('/opt/zfswatcher/zfswatcher') do
    it { should exist }
    it { should be_executable }
  end

  describe file('/opt/zfswatcher/.commit') do
    it { should exist }
    its('content') { should match(/^[a-f0-9]{40}\n?$/) }
  end
end

control 'zfswatcher-src-tree' do
  impact 1.0
  title 'cookbook-owned src tree was cloned'

  describe directory('/opt/zfswatcher/src/.git') do
    it { should exist }
  end
end

control 'zfswatcher-config' do
  impact 1.0
  title '/etc/zfswatcher/zfswatcher.conf is rendered with the configured bind addr'

  describe file('/etc/zfswatcher/zfswatcher.conf') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0640' }
    its('content') { should match(/0\.0\.0\.0:8800/) }
  end
end

control 'zfswatcher-log-dir' do
  impact 1.0
  title '/var/log/zfswatcher exists for daemon stdout/stderr'

  describe directory('/var/log/zfswatcher') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755' }
  end
end

control 'zfswatcher-systemd-unit' do
  impact 1.0
  title 'zfswatcher.service systemd unit is installed + enabled'

  describe file('/etc/systemd/system/zfswatcher.service') do
    it { should exist }
    its('content') { should match(%r{ExecStart=/opt/zfswatcher/zfswatcher -c /etc/zfswatcher/zfswatcher\.conf}) }
  end

  describe service('zfswatcher') do
    it { should be_enabled }
  end
end

control 'zfswatcher-consul-service' do
  impact 1.0
  title 'consul service-registration JSON is rendered for the port that the binary binds'

  describe file('/etc/consul.d/zfswatcher.json') do
    it { should exist }
    its('owner') { should eq 'consul' }
    its('group') { should eq 'consul' }
    its('mode')  { should cmp '0640' }
    its('content') { should match(/"port"\s*:\s*8800/) }
  end
end
