# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)).converge('cinc_client::install')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the cinc_client_install resource' do
    expect(chef_run).to install_cinc_client_install('cinc')
  end

  # --- Underlying apt_repository for cinc-project ---
  it 'registers the cinc-project apt repo' do
    expect(chef_run).to add_apt_repository('cinc-project')
      .with(uri: 'https://packagecloud.io/cinc-project/stable/debian/')
  end

  # --- Pinned cinc package install ---
  it 'installs cinc at the pinned version' do
    expect(chef_run).to install_apt_package('cinc')
      .with(version: '19.2.12-1')
  end
end
