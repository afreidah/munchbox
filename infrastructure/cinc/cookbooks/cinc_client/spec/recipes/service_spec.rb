# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# service recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::service' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_service)).converge('cinc_client::service')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the cinc_client_service resource' do
    expect(chef_run).to configure_cinc_client_service('cinc')
  end

  # --- Both systemd units are created ---
  it 'creates the cinc-client.service unit' do
    expect(chef_run).to create_systemd_unit('cinc-client.service')
  end

  it 'creates the cinc-client.timer unit' do
    expect(chef_run).to create_systemd_unit('cinc-client.timer')
  end

  # --- Default attribute leaves timer disabled (kitchen default; opt-in in prod) ---
  context 'with the default timer_enabled = false' do
    it 'disables and stops the timer' do
      expect(chef_run).to disable_systemd_unit('cinc-client.timer')
      expect(chef_run).to stop_systemd_unit('cinc-client.timer')
    end
  end

  context 'with timer_enabled = true' do
    cached(:chef_run_with_timer) do
      ChefSpec::SoloRunner.new(step_into: %w(cinc_client_service)) do |node|
        node.override[:cinc_client][:service][:timer_enabled] = true
      end.converge('cinc_client::service')
    end

    it 'enables and starts the timer' do
      expect(chef_run_with_timer).to enable_systemd_unit('cinc-client.timer')
      expect(chef_run_with_timer).to start_systemd_unit('cinc-client.timer')
    end
  end
end
