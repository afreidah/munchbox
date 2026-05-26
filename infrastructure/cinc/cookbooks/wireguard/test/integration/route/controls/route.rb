# frozen_string_literal: true

# -------------------------------------------------------------------------------
# wireguard::route integration controls.
# -------------------------------------------------------------------------------

control 'route-unit-installed' do
  impact 1.0
  title 'wireguard-route.service oneshot unit is installed + enabled with the ip-route commands baked in'

  describe file('/etc/systemd/system/wireguard-route.service') do
    it { should exist }
    its('content') { should match(%r{^ExecStart=/sbin/ip route replace 198\.51\.100\.0/24 via 192\.168\.121\.1$}) }
    its('content') { should match(%r{^ExecStop=-/sbin/ip route del 198\.51\.100\.0/24 via 192\.168\.121\.1$}) }
    its('content') { should match(/^Type=oneshot$/) }
    its('content') { should match(/^RemainAfterExit=yes$/) }
  end

  describe service('wireguard-route') do
    it { should be_enabled }
  end
end

control 'route-installed-in-kernel' do
  impact 1.0
  title 'kernel route table actually carries the configured route after the oneshot fires'

  describe command('ip -4 route show 198.51.100.0/24') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(%r{198\.51\.100\.0/24 via 192\.168\.121\.1}) }
  end
end

control 'route-legacy-sweep' do
  impact 1.0
  title 'legacy ansible-managed /etc/network/interfaces.d/wireguard-route is removed'

  describe file('/etc/network/interfaces.d/wireguard-route') do
    it { should_not exist }
  end
end
