# frozen_string_literal: true

# -------------------------------------------------------------------------------
# munchbox_base integration controls
#
# One control per recipe. Each asserts: the file(s) the resource was supposed
# to create are on disk with our marker, and the corresponding systemd unit
# is enabled+running.
# -------------------------------------------------------------------------------

control 'apt_repo' do
  impact 1.0
  title 'munchbox_base::apt_repo registers a working apt repo'

  describe file('/etc/apt/sources.list.d/nginx.list') do
    it { should exist }
    its('content') { should match(%r{nginx\.org/packages/debian}) }
  end
end

control 'packages' do
  impact 1.0
  title 'munchbox_base::packages installs the baseline package set'

  %w(curl jq).each do |pkg|
    describe package(pkg) do
      it { should be_installed }
    end
  end
end

control 'timesync' do
  impact 1.0
  title 'munchbox_base::timesync drops conf.d override and runs the service'

  describe file('/etc/systemd/timesyncd.conf.d/00-munchbox.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^NTP=.*pool\.ntp\.org/) }
  end

  describe service('systemd-timesyncd') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end

control 'journald' do
  impact 1.0
  title 'munchbox_base::journald drops conf.d override and runs the service'

  describe file('/etc/systemd/journald.conf.d/00-munchbox.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^SystemMaxUse=2G/) }
    its('content') { should match(/^MaxRetentionSec=2week/) }
  end

  describe service('systemd-journald') do
    it { should be_enabled }
    it { should be_running }
  end
end

control 'sshd' do
  impact 1.0
  title 'munchbox_base::sshd templates sshd_config and runs the service'

  describe file('/etc/ssh/sshd_config') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^PermitRootLogin prohibit-password/) }
    its('content') { should match(/^PasswordAuthentication no/) }
  end

  describe service('ssh') do
    it { should be_enabled }
    it { should be_running }
  end
end
