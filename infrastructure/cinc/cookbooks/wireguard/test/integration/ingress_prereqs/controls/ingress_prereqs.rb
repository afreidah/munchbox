# frozen_string_literal: true

# -------------------------------------------------------------------------------
# wireguard::ingress_prereqs integration controls.
# -------------------------------------------------------------------------------

control 'modules-load-dropin' do
  impact 1.0
  title '/etc/modules-load.d/wireguard.conf tells systemd to load wireguard at boot'

  describe file('/etc/modules-load.d/wireguard.conf') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0644' }
    its('content') { should match(/^wireguard$/) }
  end
end

control 'wireguard-tools' do
  impact 1.0
  title 'wireguard-tools is installed for operator wg show'

  describe package('wireguard-tools') do
    it { should be_installed }
  end

  describe command('wg --version') do
    its('exit_status') { should eq 0 }
  end
end

control 'wireguard-module-loaded' do
  impact 1.0
  title 'wireguard kernel module is loaded (debian-12 ships with it builtin/loadable)'

  describe command('lsmod') do
    its('stdout') { should match(/^wireguard /) }
  end
end

control 'keepalived-vmac-sysctl-absent' do
  impact 1.0
  title 'obsolete keepalived-vmac sysctl drop-in has been removed'

  describe file('/etc/sysctl.d/99-keepalived-vmac.conf') do
    it { should_not exist }
  end
end
