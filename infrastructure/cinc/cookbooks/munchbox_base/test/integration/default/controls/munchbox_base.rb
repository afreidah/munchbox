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

control 'apt_cleanup' do
  impact 1.0
  title 'munchbox_base::apt_cleanup empties the apt archive cache'

  # --- After `apt-get clean` the cache should only contain partial/ + lock + maybe a .gpg ---
  describe command('find /var/cache/apt/archives -maxdepth 1 -name "*.deb" | wc -l') do
    its('stdout') { should match(/^\s*0\s*$/) }
  end
end

control 'rsyslog_rotation' do
  impact 1.0
  title 'munchbox_base::rsyslog_rotation templates /etc/logrotate.d/rsyslog'

  describe file('/etc/logrotate.d/rsyslog') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(%r{^# Managed by cinc/chef -- munchbox_base::rsyslog_rotation}) }
    its('content') { should match(%r{^/var/log/syslog$}) }
    its('content') { should match(/^\s+daily$/) }
    its('content') { should match(/^\s+size 200M$/) }
    its('content') { should match(/^\s+su root syslog$/) }
    its('content') { should match(%r{^\s+/usr/lib/rsyslog/rsyslog-rotate$}) }
  end
end

control 'pki_trust' do
  impact 1.0
  title 'munchbox_base::pki_trust drops root + intermediate CAs into the system trust store'

  describe file('/usr/local/share/ca-certificates/munchbox-root-ca.crt') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/-----BEGIN CERTIFICATE-----/) }
  end

  describe file('/usr/local/share/ca-certificates/munchbox-intermediate-ca.crt') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/-----BEGIN CERTIFICATE-----/) }
  end

  # update-ca-certificates folds new PEMs into /etc/ssl/certs/ca-certificates.crt
  describe file('/etc/ssl/certs/ca-certificates.crt') do
    it { should exist }
  end
end

control 'sysctl' do
  impact 1.0
  title 'munchbox_base::sysctl drops the cluster-wide kernel knobs'

  describe file('/etc/sysctl.d/99-munchbox.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^vm\.overcommit_memory\s*=\s*1$/) }
    its('content') { should match(/^net\.ipv4\.ip_nonlocal_bind\s*=\s*1$/) }
  end

  # --- knobs are live in the kernel, not just written to the drop-in ---
  describe kernel_parameter('net.ipv4.ip_nonlocal_bind') do
    its('value') { should eq 1 }
  end
end

control 'disable_ipv6_ra' do
  impact 1.0
  title 'munchbox_base::disable_ipv6_ra drops the RA-ignore sysctl'

  describe file('/etc/sysctl.d/99-disable-ipv6-ra.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^net\.ipv6\.conf\.all\.accept_ra\s*=\s*0$/) }
    its('content') { should match(/^net\.ipv6\.conf\.default\.accept_ra\s*=\s*0$/) }
  end
end

control 'resolv_conf' do
  impact 1.0
  title 'munchbox_base::resolv_conf templates /etc/resolv.conf with the configured nameserver + search'

  describe file('/etc/resolv.conf') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^search munchbox\.cc$/) }
    its('content') { should match(/^nameserver 1\.1\.1\.1$/) }
  end
end

control 'etc_hosts' do
  impact 1.0
  title 'munchbox_base::etc_hosts renders the MUNCHBOX block with the configured static entries'

  describe file('/etc/hosts') do
    it { should exist }
    its('content') { should match(/^# BEGIN MUNCHBOX CLUSTER HOSTS$/) }
    its('content') { should match(/^# END MUNCHBOX CLUSTER HOSTS$/) }
    its('content') { should match(/^192\.168\.68\.62\s+green\s+green\.munchbox\.cc$/) }
    its('content') { should match(/^192\.168\.68\.64\s+logan\s+logan\.munchbox\.cc$/) }
  end

  describe file('/etc/cloud/cloud.cfg.d/99-disable-manage-hosts.cfg') do
    # only created if /etc/cloud/cloud.cfg.d exists on the guest; assert if present
    it 'pins cloud-init off /etc/hosts when the dir exists' do
      if directory('/etc/cloud/cloud.cfg.d').exist?
        expect(file('/etc/cloud/cloud.cfg.d/99-disable-manage-hosts.cfg')).to exist
      end
    end
  end
end
