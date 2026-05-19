# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec -- step into the wrapping resource so we cover the
# underlying remote_file + dpkg_package it declares.
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_server::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_server_install)).converge('cinc_server::install')
  end

  # --- Declares the wrapping resource keyed by 'cinc-server' ---
  it 'declares the cinc_server_install resource' do
    expect(chef_run).to install_cinc_server_install('cinc-server')
  end

  # --- Underlying dpkg_package is queued at the pinned version ---
  it 'installs cinc-server-core at the pinned version' do
    expect(chef_run).to install_dpkg_package('cinc-server-core')
      .with(version: '15.10.91-1')
  end
end
