# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Inspec controls for the consul cookbook (kitchen suite).
#
# Single-node bootstrap (server=true, bootstrap_expect=1, ACL+TLS off).
# Validates the binary is installed, the systemd unit is up, the rendered
# config matches the kitchen attributes, and the agent is actually serving
# HTTP -- the only end-to-end signal that consul is alive.
# -------------------------------------------------------------------------------

# --- Binary present + correct version (pinned in attributes/default.rb) ---
control 'consul-binary' do
  impact 1.0
  title 'consul binary is installed at /usr/local/bin/consul'

  describe file('/usr/local/bin/consul') do
    it { should exist }
    it { should be_executable }
  end

  describe command('/usr/local/bin/consul version') do
    its('stdout') { should match(/Consul v1\.22\.7/) }
  end
end

# --- Service: enabled + running, owned by the consul user ---
control 'consul-service' do
  impact 1.0
  title 'consul.service is enabled and running'

  describe service('consul') do
    it { should be_enabled }
    it { should be_running }
  end
end

# --- Rendered config has the chef-managed header + the toggles kitchen set ---
control 'consul-config' do
  impact 1.0
  title '/etc/consul.d/consul.hcl matches the requested config'

  describe file('/etc/consul.d/consul.hcl') do
    it { should exist }
    it { should be_owned_by 'consul' }
    it { should be_grouped_into 'consul' }
    its('mode') { should cmp '0640' }
    its('content') { should match(/Managed by chef \(consul::configure\)/) }
    its('content') { should match(/datacenter\s*=\s*"munchbox"/) }
    its('content') { should match(/bind_addr\s*=\s*"127\.0\.0\.1"/) }
    its('content') { should match(/server\s*=\s*true/) }
    its('content') { should match(/bootstrap_expect\s*=\s*1/) }
  end
end

# --- ACL + TLS sections should be absent (kitchen sets both false) ---
control 'consul-config-no-acl-no-tls' do
  impact 0.7
  title 'ACL + TLS blocks are NOT rendered when kitchen disables them'

  describe file('/etc/consul.d/consul.hcl') do
    its('content') { should_not match(/^acl\s*\{/) }
    its('content') { should_not match(/^tls\s*\{/) }
  end
end

# --- End-to-end: the HTTP API actually serves; status/leader returns a value once raft has elected self ---
control 'consul-http-api' do
  impact 0.9
  title 'consul HTTP API serves status/leader (agent is up + elected)'

  describe command('curl -sS --max-time 5 http://127.0.0.1:8500/v1/status/leader') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/"127\.0\.0\.1:8300"/) }
  end
end
