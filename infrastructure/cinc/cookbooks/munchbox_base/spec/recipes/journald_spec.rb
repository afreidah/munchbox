# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# journald recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::journald' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_journald)).converge('munchbox_base::journald')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the journald wrapping resource' do
    expect(chef_run).to configure_munchbox_base_journald('baseline')
  end

  # --- conf.d directory + drop-in get created with correct perms ---
  it 'creates the journald conf.d directory' do
    expect(chef_run).to create_directory('/etc/systemd/journald.conf.d')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  it 'renders the journald drop-in' do
    expect(chef_run).to create_template('/etc/systemd/journald.conf.d/00-munchbox.conf')
  end

  # --- Service is enabled + started, restart fires on drop-in change ---
  it 'enables and starts systemd-journald' do
    expect(chef_run).to enable_service('systemd-journald')
    expect(chef_run).to start_service('systemd-journald')
  end

  it 'queues a delayed restart when the drop-in changes' do
    template = chef_run.template('/etc/systemd/journald.conf.d/00-munchbox.conf')
    expect(template).to notify('service[systemd-journald]').to(:restart).delayed
  end
end
