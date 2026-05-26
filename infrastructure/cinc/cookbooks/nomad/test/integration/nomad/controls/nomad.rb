# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Inspec controls for the nomad cookbook (kitchen suite).
#
# Single-node mixed server+client (ACL+TLS+Consul+Vault all off in the
# kitchen attributes). Validates the binary is installed, the systemd
# unit is up, the rendered config matches expectation, and the agent
# is actually serving its HTTP API.
# -------------------------------------------------------------------------------

# --- Binary present + correct version (pinned in attributes/default.rb) ---
control 'nomad-binary' do
  impact 1.0
  title 'nomad binary is installed at /usr/local/bin/nomad'

  describe file('/usr/local/bin/nomad') do
    it { should exist }
    it { should be_executable }
  end

  describe command('/usr/local/bin/nomad version') do
    its('stdout') { should match(/Nomad v2\.0\.2/) }
  end
end

# --- Service: enabled + running, owned by the nomad user ---
control 'nomad-service' do
  impact 1.0
  title 'nomad.service is enabled and running'

  describe service('nomad') do
    it { should be_enabled }
    it { should be_running }
  end
end

# --- Rendered config has the chef-managed header + the toggles kitchen set ---
control 'nomad-config' do
  impact 1.0
  title '/etc/nomad.d/nomad.hcl matches the requested config'

  describe file('/etc/nomad.d/nomad.hcl') do
    it { should exist }
    it { should be_owned_by 'nomad' }
    it { should be_grouped_into 'nomad' }
    its('mode') { should cmp '0640' }
    its('content') { should match(/Managed by chef \(nomad::configure\)/) }
    its('content') { should match(/datacenter\s*=\s*"munchbox"/) }
    its('content') { should match(/bind_addr\s*=\s*"127\.0\.0\.1"/) }
    its('content') { should match(/server\s*\{/) }
    its('content') { should match(/bootstrap_expect\s*=\s*1/) }
  end
end

# --- Disabled blocks (ACL, TLS, Consul, Vault) should NOT be rendered when kitchen turns them off ---
control 'nomad-config-disabled-blocks' do
  impact 0.7
  title 'consul / vault / TLS / client blocks are absent when disabled by kitchen attrs'

  describe file('/etc/nomad.d/nomad.hcl') do
    its('content') { should_not match(/^consul\s*\{/) }
    its('content') { should_not match(/^vault\s*\{/) }
    its('content') { should_not match(/^client\s*\{/) }
    its('content') { should match(/^acl\s*\{[^}]*enabled\s*=\s*false/m) }
    its('content') { should match(/http\s*=\s*false/) }
  end
end

# --- End-to-end: the HTTP API actually serves; agent/self returns once raft has elected self ---
control 'nomad-http-api' do
  impact 0.9
  title 'nomad HTTP API serves agent/self (agent is up + elected)'

  describe command('curl -sS --max-time 5 http://127.0.0.1:4646/v1/agent/self') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/"NodeName":/) }
    its('stdout') { should match(/"Server":\s*true/) }
  end
end
