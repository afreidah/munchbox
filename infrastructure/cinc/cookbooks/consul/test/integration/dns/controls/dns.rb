# frozen_string_literal: true

# -------------------------------------------------------------------------------
# consul::dns integration controls.
# -------------------------------------------------------------------------------

control 'dnsmasq-installed' do
  impact 1.0
  title 'dnsmasq package is installed'

  describe package('dnsmasq') do
    it { should be_installed }
  end
end

control 'dnsmasq-config' do
  impact 1.0
  title '/etc/dnsmasq.d/consul.conf forwards .consul + lists pi-hole fallbacks'

  describe file('/etc/dnsmasq.d/consul.conf') do
    it { should exist }
    its('content') { should match(%r{^server=/consul/}) }
    its('content') { should match(/^listen-address=127\.0\.0\.53/) }
    its('content') { should match(/^server=192\.168\.68\.62$/) }
    its('content') { should match(/^server=192\.168\.68\.64$/) }
  end
end

control 'dnsmasq-running' do
  impact 1.0
  title 'dnsmasq systemd unit is enabled + running'

  describe service('dnsmasq') do
    it { should be_enabled }
    it { should be_running }
  end
end

control 'systemd-resolved-disabled' do
  impact 1.0
  title 'systemd-resolved is stopped + disabled (it would conflict on :53)'

  describe service('systemd-resolved') do
    it { should_not be_enabled }
    it { should_not be_running }
  end
end

control 'avahi-disabled' do
  impact 1.0
  title 'avahi is stopped + disabled (mDNS would collide on :5353)'

  describe service('avahi-daemon') do
    it { should_not be_running }
  end
end

control 'resolv-conf-takeover' do
  impact 1.0
  title '/etc/resolv.conf points at the dnsmasq listener'

  describe file('/etc/resolv.conf') do
    it { should exist }
    its('content') { should match(/^nameserver 127\.0\.0\.53$/) }
    its('content') { should match(/^search munchbox\.cc$/) }
  end
end
