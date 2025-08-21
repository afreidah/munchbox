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

  # Check all three consul@ instances are enabled and running
  (1..3).each do |i|
    describe service("consul@#{i}") do
      it { should be_enabled }
      it { should be_running }
    end
  end

  describe package('ufw') do
    it { should be_installed }
  end

  # Check all expected ports for all three instances
  [0, 10, 20].each do |offset|
    [
      { port: 8300 + offset, proto: 'tcp' },
      { port: 8301 + offset, proto: 'tcp' },
      { port: 8301 + offset, proto: 'udp' },
      { port: 8302 + offset, proto: 'tcp' },
      { port: 8302 + offset, proto: 'udp' },
      { port: 8500 + offset, proto: 'tcp' },
      { port: 8600 + offset, proto: 'tcp' },
      { port: 8600 + offset, proto: 'udp' },
    ].each do |rule|
      describe command("ufw status | grep '192.168.1.0/24' | grep '#{rule[:port]}' | grep '#{rule[:proto]}'") do
        its('exit_status') { should eq 0 }
      end
    end
  end

  # Check each instance's members and cluster health
  (1..3).each do |i|
    http_port = 8500 + (i - 1) * 10
    describe command("CONSUL_HTTP_ADDR=http://127.0.0.1:#{http_port} consul members") do
      its('exit_status') { should eq 0 }
      its('stdout') { should match(/^.+\n.+\n.+\n/) }
      it 'shows exactly three members' do
        expect(subject.stdout.lines.reject { |l| l.strip.empty? }.count).to eq 3
      end
    end
  end
end
