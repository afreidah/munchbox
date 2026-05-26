# frozen_string_literal: true

# -------------------------------------------------------------------------------
# cinc_client integration controls
#
# Static-config verification only; cinc-client is never actually run in
# kitchen (no reachable cinc-server). Asserts package presence, config
# content, cert + validator drop locations + perms, and systemd unit
# installation. Timer is expected to be disabled (kitchen default).
# -------------------------------------------------------------------------------

control 'install' do
  impact 1.0
  title 'cinc_client::install installs the cinc package + repo'

  describe package('cinc') do
    it { should be_installed }
  end

  describe file('/etc/apt/sources.list.d/cinc-project.list') do
    it { should exist }
    its('content') { should match(%r{packagecloud\.io/cinc-project/stable/debian}) }
  end

  describe file('/usr/bin/cinc-client') do
    it { should exist }
    it { should be_executable }
  end
end

control 'configure' do
  impact 1.0
  title 'cinc_client::configure drops client.rb + trusted cert + validator'

  describe directory('/etc/cinc') do
    it { should exist }
    its('mode') { should cmp '0755' }
    its('owner') { should eq 'root' }
  end

  describe directory('/etc/cinc/trusted_certs') do
    it { should exist }
    its('mode') { should cmp '0755' }
  end

  describe directory('/var/log/cinc') do
    it { should exist }
    its('mode') { should cmp '0755' }
  end

  describe file('/etc/cinc/client.rb') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('content') { should match(%r{^chef_server_url\s+'https://cinc-server\.test/organizations/munchbox'$}) }
    its('content') { should match(/^validation_client_name\s+'munchbox-validator'$/) }
    its('content') { should match(%r{^client_key\s+'/etc/cinc/client\.pem'$}) }
    its('content') { should match(%r{^trusted_certs_dir\s+'/etc/cinc/trusted_certs'$}) }
    its('content') { should match(/^log_level\s+:info$/) }
  end

  describe file('/etc/cinc/trusted_certs/cinc-server.crt') do
    it { should exist }
    its('mode') { should cmp '0644' }
    its('owner') { should eq 'root' }
    its('content') { should match(/KITCHEN-TEST-CERT-PLACEHOLDER/) }
  end

  describe file('/etc/cinc/validation.pem') do
    it { should exist }
    its('mode') { should cmp '0600' }
    its('owner') { should eq 'root' }
    its('content') { should match(/KITCHEN-TEST-VALIDATOR-PLACEHOLDER/) }
  end
end

control 'service' do
  impact 1.0
  title 'cinc_client::service installs systemd units; timer disabled by default'

  describe file('/etc/systemd/system/cinc-client.service') do
    it { should exist }
    its('content') { should match(%r{^ExecStart=/usr/bin/cinc-client$}) }
    its('content') { should match(/^Type=oneshot$/) }
  end

  describe file('/etc/systemd/system/cinc-client.timer') do
    it { should exist }
    its('content') { should match(/^OnCalendar=hourly$/) }
    its('content') { should match(/^Persistent=true$/) }
  end

  # --- Timer is disabled per kitchen default; flipping the attribute in production enables it ---
  describe service('cinc-client.timer') do
    it { should_not be_enabled }
    it { should_not be_running }
  end
end

control 'disable-apt-daily' do
  impact 1.0
  title 'unattended-upgrades-style apt timers + services are stopped, disabled, and masked'

  %w(apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service).each do |unit|
    describe command("systemctl is-enabled #{unit}") do
      # `masked` is what `systemd_unit action :mask` produces; `disabled` is the pre-mask state
      its('stdout') { should match(/^(masked|disabled)$/) }
    end

    describe command("systemctl is-active #{unit}") do
      # timers report 'inactive' when not running; services report same
      its('stdout') { should match(/^(inactive|failed)$/) }
    end
  end
end
