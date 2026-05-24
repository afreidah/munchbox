# frozen_string_literal: true

# -------------------------------------------------------------------------------
# vault_agent integration controls
#
# Static-config verification only: vault binary installed, /etc/vault.d/
# files in place, vault-agent.service unit installed + active. Does NOT
# verify Vault Agent successfully auth's to a real Vault (no reachable
# Vault in kitchen); the agent will sit in a retry loop, which keeps the
# systemd unit `active (running)` regardless.
# -------------------------------------------------------------------------------

control 'install' do
  impact 1.0
  title 'vault_agent::install installs vault + creates /etc/vault.d'

  describe package('vault') do
    it { should be_installed }
  end

  describe file('/usr/bin/vault') do
    it { should exist }
    it { should be_executable }
  end

  describe directory('/etc/vault.d') do
    it { should exist }
    its('mode') { should cmp '0700' }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
  end

  # --- Upstream server-mode unit is masked so it can't fight our agent unit ---
  describe command('systemctl is-enabled vault.service') do
    its('stdout') { should match(/^masked$/) }
  end
end

control 'configure' do
  impact 1.0
  title 'vault_agent::configure drops creds + agent.hcl + runs the service'

  describe file('/etc/vault.d/role_id') do
    it { should exist }
    its('mode') { should cmp '0640' }
    its('owner') { should eq 'root' }
  end

  describe file('/etc/vault.d/secret_id') do
    it { should exist }
    its('mode') { should cmp '0640' }
    its('owner') { should eq 'root' }
  end

  describe file('/etc/vault.d/agent.hcl') do
    it { should exist }
    its('mode') { should cmp '0640' }
    its('content') { should match(%r{^\s*address = "https://vault\.test:8200"}) }
    its('content') { should match(%r{^\s*mount_path = "auth/chef-approle"}) }
    its('content') { should match(%r{role_id_file_path\s*=\s*"/etc/vault\.d/role_id"}) }
    its('content') { should match(%r{secret_id_file_path\s*=\s*"/etc/vault\.d/secret_id"}) }
  end

  describe file('/etc/systemd/system/vault-agent.service') do
    it { should exist }
    its('content') { should match(%r{^ExecStart=/usr/bin/vault agent -config=/etc/vault\.d/agent\.hcl}) }
    its('content') { should match(/^RuntimeDirectory=vault-agent/) }
  end

  describe service('vault-agent') do
    it { should be_enabled }
    it { should be_running }
  end

  describe directory('/run/vault-agent') do
    it { should exist }
  end
end
