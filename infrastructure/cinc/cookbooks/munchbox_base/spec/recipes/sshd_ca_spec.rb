# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# sshd_ca recipe spec
#
# Covers the Vault SSH CA wiring: trusted user CA pubkey, per-user
# authorized_principals files, sshd_config.d drop-in, break-glass key.
# vault_fetch is stubbed since chefspec doesn't have a real
# /run/vault-agent/token.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::sshd_ca' do
  before do
    %i(Recipe Resource).each do |klass|
      allow_any_instance_of(Chef.const_get(klass)).to receive(:vault_fetch) do |_, path, _|
        case path
        when /client-signer/ then 'ssh-ed25519 AAAA-client-ca-key'
        when /host-signer/   then 'ssh-ed25519 AAAA-host-ca-key'
        when /break-glass/   then 'ssh-ed25519 AAAA-break-glass-key'
        end
      end
    end
  end

  # -------------------------------------------------------------------------------
  # Default principals (root only)
  # -------------------------------------------------------------------------------
  context 'with default principals' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_sshd)).converge('munchbox_base::sshd_ca')
    end

    it 'declares the munchbox_base_sshd wrapping resource (action :configure_ca)' do
      expect(chef_run).to configure_ca_munchbox_base_sshd('ca')
    end

    it 'declares the sshd_config.d drop-in file resource' do
      expect(chef_run).to create_file('/etc/ssh/sshd_config.d/10-munchbox-ssh-ca.conf')
    end

    it 'creates /root/.ssh and pins the host CA in known_hosts via ruby_block' do
      expect(chef_run).to create_directory('/root/.ssh')
      expect(chef_run).to run_ruby_block('pin host CA in /root/.ssh/known_hosts')
      expect(chef_run).to run_ruby_block('break-glass key in root authorized_keys')
    end

    it 'writes the trusted_user_ca file' do
      expect(chef_run).to create_file('/etc/ssh/trusted-user-ca-keys.pem')
        .with(owner: 'root', group: 'root', mode: '0644')
    end

    it 'creates the principals directory + root principals file' do
      expect(chef_run).to create_directory('/etc/ssh/authorized_principals')
        .with(owner: 'root', group: 'root', mode: '0755')
      expect(chef_run).to create_file('/etc/ssh/authorized_principals/root')
        .with(content: "root\n", owner: 'root', group: 'root', mode: '0644')
    end

    it 'drops the sshd ssh-ca drop-in pointing at the host cert + trusted CA + principals dir' do
      drop_in = chef_run.file('/etc/ssh/sshd_config.d/10-munchbox-ssh-ca.conf')
      expect(drop_in).to_not be_nil
      expect(drop_in.content).to match(%r{^HostCertificate /etc/ssh/ssh_host_ed25519_key-cert\.pub$})
      expect(drop_in.content).to match(%r{^TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys\.pem$})
      expect(drop_in.content).to match(%r{^AuthorizedPrincipalsFile /etc/ssh/authorized_principals/%u$})
    end

    it 'notifies a delayed ssh restart when the drop-in changes' do
      expect(chef_run.file('/etc/ssh/sshd_config.d/10-munchbox-ssh-ca.conf'))
        .to notify('service[ssh]').to(:restart).delayed
    end
  end

  # -------------------------------------------------------------------------------
  # Extra principals (e.g. ubuntu on oracle nodes)
  # -------------------------------------------------------------------------------
  context 'with extra principals (e.g. ubuntu on oracle nodes)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_sshd)) do |node|
        node.override[:munchbox_base][:ssh_ca][:principals] = {
          'root' => ['root'],
          'ubuntu' => ['ubuntu'],
        }
      end.converge('munchbox_base::sshd_ca')
    end

    it 'creates a principals file per user' do
      expect(chef_run).to create_file('/etc/ssh/authorized_principals/ubuntu')
        .with(content: "ubuntu\n")
    end
  end
end
