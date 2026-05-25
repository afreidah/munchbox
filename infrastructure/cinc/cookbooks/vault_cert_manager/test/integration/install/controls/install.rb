# frozen_string_literal: true

# -------------------------------------------------------------------------------
# vault_cert_manager::install integration controls.
# -------------------------------------------------------------------------------

control 'package' do
  impact 1.0
  title 'vault-cert-manager apt package is installed'

  describe package('vault-cert-manager') do
    it { should be_installed }
  end
end

control 'binary' do
  impact 1.0
  title '/usr/bin/vault-cert-manager binary is on disk + executable'

  describe file('/usr/bin/vault-cert-manager') do
    it { should exist }
    it { should be_executable }
  end
end

control 'config-dir' do
  impact 1.0
  title '/etc/vault-cert-manager exists root:root 0755'

  describe directory('/etc/vault-cert-manager') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755' }
  end
end

control 'consul-user' do
  impact 1.0
  title 'consul system user + group exist as cert-owner prereq'

  describe group('consul') do
    it { should exist }
  end

  describe user('consul') do
    it { should exist }
    its('shell') { should eq '/bin/false' }
  end
end
