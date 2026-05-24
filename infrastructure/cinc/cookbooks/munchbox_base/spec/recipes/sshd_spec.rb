# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# sshd recipe spec
#
# Covers baseline sshd hardening only. SSH CA wiring lives in the sshd_ca
# recipe and has its own spec.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::sshd' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_sshd)).converge('munchbox_base::sshd')
  end

  it 'declares the sshd wrapping resource' do
    expect(chef_run).to configure_munchbox_base_sshd('baseline')
  end

  it 'templates /etc/ssh/sshd_config 0644 root:root' do
    expect(chef_run).to create_template('/etc/ssh/sshd_config')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  it 'enables and starts ssh' do
    expect(chef_run).to enable_service('ssh')
    expect(chef_run).to start_service('ssh')
  end

  it 'queues a delayed restart when sshd_config changes' do
    expect(chef_run.template('/etc/ssh/sshd_config'))
      .to notify('service[ssh]').to(:restart).delayed
  end

  # --- CA bits live in sshd_ca and must NOT be touched here ---
  it 'does NOT drop the trusted user CA file' do
    expect(chef_run).to_not create_file('/etc/ssh/trusted-user-ca-keys.pem')
  end

  it 'does NOT drop the sshd ssh-ca drop-in' do
    expect(chef_run).to_not create_file('/etc/ssh/sshd_config.d/10-munchbox-ssh-ca.conf')
  end
end
