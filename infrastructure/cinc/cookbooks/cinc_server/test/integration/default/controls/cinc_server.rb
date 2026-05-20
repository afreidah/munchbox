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

  # --- cron is a debian-12-cloud-image prereq for infra-server::log_cleanup ---
  describe package('cron') do
    it { should be_installed }
  end
end

control 'configure' do
  impact 1.0
  title 'cinc_server::configure templates chef-server.rb and reconfigures the server'

  describe directory('/etc/opscode') do
    it { should exist }
    its('mode') { should cmp '0755' }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
  end

  describe file('/etc/opscode/chef-server.rb') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(/^api_fqdn 'cinc-server\.test'/) }
    its('content') { should match(/^nginx\['server_name'\] 'cinc-server\.test'/) }
    its('content') { should match(%r{^nginx\['ssl_certificate'\] '/etc/opscode/certs/cinc-server\.test\.crt'}) }
    its('content') { should match(%r{^nginx\['ssl_certificate_key'\] '/etc/opscode/certs/cinc-server\.test\.key'}) }
    its('content') { should match(/^nginx\['enable_non_ssl'\] true/) }
  end

  # --- Hostname was set to api_fqdn so anything that defaults to it (e.g. ohai) is right ---
  describe command('hostname') do
    its('stdout') { should match(/^cinc-server\.test/) }
  end

  # --- Cert + key are owned by the cookbook (out of cinc-server's auto-gen tree) ---
  describe directory('/etc/opscode/certs') do
    it { should exist }
    its('mode') { should cmp '0755' }
    its('owner') { should eq 'root' }
  end

  describe file('/etc/opscode/certs/cinc-server.test.crt') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('owner') { should eq 'root' }
  end

  describe file('/etc/opscode/certs/cinc-server.test.key') do
    it { should exist }
    its('mode') { should cmp '0600' }
    its('owner') { should eq 'root' }
  end

  describe x509_certificate('/etc/opscode/certs/cinc-server.test.crt') do
    its('subject.CN') { should eq 'cinc-server.test' }
    its('subject_alt_names') { should include 'DNS:cinc-server.test' }
    its('subject_alt_names') { should include 'DNS:cinc-server' }
  end

  # --- Cert served by nginx on 443 must be the one we own, not cinc-server's auto-cert ---
  describe command('openssl s_client -connect localhost:443 -servername cinc-server.test </dev/null 2>/dev/null | openssl x509 -noout -subject') do
    its('stdout') { should match(/CN\s*=\s*cinc-server\.test/) }
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

  # --- /_status hits nginx -> opscode-erchef -> postgres -> bifrost; "pong" proves chef-server is responding end-to-end ---
  describe command('curl -ksf https://localhost/_status') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/"status":\s*"pong"/) }
  end
end

control 'bootstrap' do
  impact 1.0
  title 'cinc_server::bootstrap creates the initial org + admin user'

  describe directory('/etc/cinc-bootstrap') do
    it { should exist }
    its('mode') { should cmp '0700' }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
  end

  describe command("chef-server-ctl org-show 'munchbox'") do
    its('exit_status') { should eq 0 }
  end

  describe command("chef-server-ctl user-show 'alex'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/email:\s*alex\.freidah@gmail\.com/) }
  end

  describe file('/etc/cinc-bootstrap/alex.pem') do
    it { should exist }
    its('mode') { should cmp '0600' }
    its('owner') { should eq 'root' }
    its('content') { should match(/BEGIN (RSA )?PRIVATE KEY/) }
  end

  # --- alex should be a member of the munchbox org (cinc-15.10.91 doesn't accept `org-user-list <org>`; use user-show --with-orgs) ---
  describe command("chef-server-ctl user-show 'alex' --with-orgs") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/^organizations:.*\bmunchbox\b/) }
  end
end
