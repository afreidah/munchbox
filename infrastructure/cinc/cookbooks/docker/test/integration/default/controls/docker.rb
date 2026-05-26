# frozen_string_literal: true

# -------------------------------------------------------------------------------
# docker integration controls
#
# One control per recipe. install asserts the apt suite + service is up;
# configure asserts the rendered daemon.json matches the kitchen attrs.
# -------------------------------------------------------------------------------

control 'install' do
  impact 1.0
  title 'docker::install installs docker-ce + brings the daemon up'

  describe package('docker-ce') do
    it { should be_installed }
  end

  describe package('containerd.io') do
    it { should be_installed }
  end

  describe service('docker') do
    it { should be_enabled }
    it { should be_running }
  end

  describe file('/etc/apt/sources.list.d/docker.list') do
    it { should exist }
    its('content') { should match(%r{download\.docker\.com/linux/debian}) }
  end
end

control 'configure' do
  impact 1.0
  title 'docker::configure templates daemon.json with the kitchen attributes'

  describe file('/etc/docker/daemon.json') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/"dns":/) }
    its('content') { should match(/"1\.1\.1\.1"/) }
    # --- storage-driver intentionally omitted from attribute defaults; would stomp overlayfs nodes ---
    its('content') { should_not match(/"storage-driver"/) }
    its('content') { should match(/"log-driver":\s*"json-file"/) }
  end

  # --- daemon.json is valid JSON ---
  describe command('python3 -c "import json; json.load(open(\'/etc/docker/daemon.json\'))"') do
    its('exit_status') { should eq 0 }
  end
end
