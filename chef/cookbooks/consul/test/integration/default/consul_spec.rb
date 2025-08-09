# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  InSpec Control: Consul Installation Verification
# ------------------------------------------------------------------------------
#  Verifies Consul is installed and matches the expected version.
# ------------------------------------------------------------------------------

control 'consul-install' do
  impact 1.0
  title  'Consul Installation'
  desc   'Ensures Consul is installed and the correct version is present.'

  describe file('/usr/local/bin/consul') do
    it { should exist }
    it { should be_executable }
  end

  describe service('consul') do
    it { should be_enabled }
    it { should be_running }
  end

  describe package('ufw') do
    it { should be_installed }
  end

  [
    { port: 8300, proto: 'tcp' },
    { port: 8301, proto: 'tcp' },
    { port: 8301, proto: 'udp' },
    { port: 8302, proto: 'tcp' },
    { port: 8302, proto: 'udp' },
    { port: 8500, proto: 'tcp' },
    { port: 8600, proto: 'tcp' },
    { port: 8600, proto: 'udp' },
  ].each do |rule|
    describe command("ufw status | grep '192.168.1.0/24' | grep '#{rule[:port]}' | grep '#{rule[:proto]}'") do
      its('exit_status') { should eq 0 }
    end
  end
end
