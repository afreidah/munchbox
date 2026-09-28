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
  # Pruning authorized_keys entries that shadow the CA
  # -------------------------------------------------------------------------------
  context 'with an authorized_keys entry that shadows the CA' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_sshd)).converge('munchbox_base::sshd_ca')
    end

    # Guarded by only_if on the file existing, so what is asserted here is that
    # the block is declared; the pruning itself is exercised below.
    it 'declares a prune block for each managed user' do
      expect(chef_run.ruby_block('prune shadowing keys from root authorized_keys')).to_not be_nil
    end

    it 'keeps every line that carries no pruned pattern' do
      kept = "ssh-ed25519 AAAA-break-glass-key break-glass@munchbox\n"
      shadow = %(no-port-forwarding,command="echo 'Please login as the user \\"ubuntu\\"'" ssh-ed25519 AAAA\n)

      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/root/.ssh/authorized_keys').and_return(true)
      allow(::File).to receive(:readlines).and_call_original
      allow(::File).to receive(:readlines).with('/root/.ssh/authorized_keys').and_return([shadow, kept])
      allow(::File).to receive(:chmod).and_call_original
      allow(::File).to receive(:chmod).with(0o600, '/root/.ssh/authorized_keys').and_return(1)

      expect(::File).to receive(:write).with('/root/.ssh/authorized_keys', kept)

      chef_run.ruby_block('prune shadowing keys from root authorized_keys').block.call
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
