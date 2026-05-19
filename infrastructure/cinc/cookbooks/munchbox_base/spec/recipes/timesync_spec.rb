# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# timesync recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::timesync' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_timesync)).converge('munchbox_base::timesync')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the timesync wrapping resource' do
    expect(chef_run).to configure_munchbox_base_timesync('baseline')
  end

  # --- conf.d directory + drop-in get created with correct perms ---
  it 'creates the timesyncd conf.d directory' do
    expect(chef_run).to create_directory('/etc/systemd/timesyncd.conf.d')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  it 'renders the timesyncd drop-in' do
    expect(chef_run).to create_template('/etc/systemd/timesyncd.conf.d/00-munchbox.conf')
  end

  # --- Service is enabled + started, restart fires on drop-in change ---
  it 'enables and starts the timesync service' do
    expect(chef_run).to enable_service('systemd-timesyncd')
    expect(chef_run).to start_service('systemd-timesyncd')
  end

  it 'queues a delayed restart when the drop-in changes' do
    template = chef_run.template('/etc/systemd/timesyncd.conf.d/00-munchbox.conf')
    expect(template).to notify('service[systemd-timesyncd]').to(:restart).delayed
  end
end
