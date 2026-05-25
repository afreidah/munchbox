# frozen_string_literal: true

# -------------------------------------------------------------------------------
# vault::install integration controls.
# -------------------------------------------------------------------------------

control 'vault-binary' do
  impact 1.0
  title 'vault binary is installed at the expected version + path'

  describe file('/usr/local/bin/vault') do
    it { should exist }
    it { should be_executable }
  end

  describe command('/usr/local/bin/vault version') do
    its('stdout') { should match(/Vault v2\.0\.1/) }
    its('exit_status') { should eq 0 }
  end
end

control 'vault-user' do
  impact 1.0
  title 'vault system user + group exist with the no-login shell'

  describe group('vault') do
    it { should exist }
  end

  describe user('vault') do
    it { should exist }
    its('group') { should eq 'vault' }
    its('shell') { should eq '/bin/false' }
  end
end

control 'vault-dirs' do
  impact 1.0
  title 'vault config + data + tls dirs exist with vault:vault 0750'

  %w(/etc/vault.d /opt/vault/data /etc/vault.d/tls).each do |d|
    describe directory(d) do
      it { should exist }
      its('owner') { should eq 'vault' }
      its('group') { should eq 'vault' }
      its('mode')  { should cmp '0750' }
    end
  end
end
