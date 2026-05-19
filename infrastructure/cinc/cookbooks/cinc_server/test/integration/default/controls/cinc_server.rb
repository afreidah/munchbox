# frozen_string_literal: true

# -------------------------------------------------------------------------------
# cinc_server integration controls
#
# One control per recipe. Verify: the package + binaries are on disk, the
# templated config is what we expect, and `chef-server-ctl status` reports
# every service as running.
# -------------------------------------------------------------------------------

control 'install' do
  impact 1.0
  title 'cinc_server::install installs the cinc-server-core package'

  describe package('cinc-server-core') do
    it { should be_installed }
  end

  describe file('/usr/bin/chef-server-ctl') do
    it { should exist }
    it { should be_executable }
  end
end

control 'configure' do
  impact 1.0
  title 'cinc_server::configure templates chef-server.rb and reconfigures the server'

  describe file('/etc/opscode/chef-server.rb') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^api_fqdn 'cinc-server\.test'/) }
  end

  # --- Top-level systemd unit that owns the runit supervisor for all
  # chef-server services. If this is down, nothing else can be up. ---
  describe service('private_chef-runsvdir-start') do
    it { should be_enabled }
    it { should be_running }
  end

  # --- runit reports each managed service as "run:" -- this is the
  # canonical chef-server health check ---
  describe command('chef-server-ctl status') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/run: postgresql:/) }
    its('stdout') { should match(/run: nginx:/) }
    its('stdout') { should match(/run: opscode-erchef:/) }
  end

  # --- /_status hits nginx -> opscode-erchef -> postgres -> bifrost, so
  # "pong" here proves chef-server itself is responding end-to-end, not
  # just nginx returning a 200 ---
  describe command('curl -ksf https://localhost/_status') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/"status":\s*"pong"/) }
  end
end
