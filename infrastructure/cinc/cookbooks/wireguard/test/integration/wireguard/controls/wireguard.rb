# frozen_string_literal: true

# -------------------------------------------------------------------------------
# wireguard integration controls
#
# Verifies static config + service state on a kitchen VM with one
# interface (wg-kitchen). No real peer handshake (no other peer in the
# VM); peer block is rendered and `wg show` reports the interface up.
# -------------------------------------------------------------------------------

control 'install' do
  impact 1.0
  title 'wireguard::install installs packages + creates /etc/wireguard'

  describe package('wireguard') do
    it { should be_installed }
  end

  describe package('wireguard-tools') do
    it { should be_installed }
  end

  describe directory('/etc/wireguard') do
    it { should exist }
    its('mode') { should cmp '0700' }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
  end

  describe kernel_parameter('net.ipv4.ip_forward') do
    its('value') { should eq 1 }
  end

  describe file('/usr/bin/wg') do
    it { should exist }
  end
end

control 'configure' do
  impact 1.0
  title 'wireguard::configure renders the interface config + brings the link up'

  describe file('/etc/wireguard/wg-kitchen.conf') do
    it { should exist }
    its('mode') { should cmp '0600' }
    its('owner') { should eq 'root' }
    its('content') { should match(%r{^Address = 10\.99\.0\.1/24}) }
    its('content') { should match(/^ListenPort = 51820/) }
    its('content') { should match(/^MTU = 1380/) }
    its('content') { should match(/^PrivateKey = /) }
    its('content') { should match(/^PostUp = iptables -I INPUT/) }
    its('content') { should match(/^\[Peer\]/) }
    its('content') { should match(/^PublicKey = /) }
  end

  describe service('wg-quick@wg-kitchen') do
    it { should be_enabled }
    it { should be_running }
  end

  # --- `wg show <iface>` reports the interface up + has our public key + peer ---
  describe command('wg show wg-kitchen') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/interface: wg-kitchen/) }
    its('stdout') { should match(/listening port: 51820/) }
    its('stdout') { should match(/peer:/) }
  end
end
