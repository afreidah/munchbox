# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# sshd recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::sshd' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_sshd)).converge('munchbox_base::sshd')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the sshd wrapping resource' do
    expect(chef_run).to configure_munchbox_base_sshd('baseline')
  end

  # --- sshd_config is templated end-to-end with correct perms ---
  it 'templates /etc/ssh/sshd_config' do
    expect(chef_run).to create_template('/etc/ssh/sshd_config')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  # --- Service is enabled + started, restart fires on config change ---
  it 'enables and starts ssh' do
    expect(chef_run).to enable_service('ssh')
    expect(chef_run).to start_service('ssh')
  end

  it 'queues a delayed restart when sshd_config changes' do
    template = chef_run.template('/etc/ssh/sshd_config')
    expect(template).to notify('service[ssh]').to(:restart).delayed
  end
end
