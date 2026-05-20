# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# apt_repo recipe spec
#
# Step into the wrapping resource so we also cover the underlying
# apt_repository chef resource it declares.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::apt_repo' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_apt_repo)).converge('munchbox_base::apt_repo')
  end

  # --- Declares the wrapping resource keyed by the configured repo name ---
  it 'declares the munchbox apt_repo resource' do
    expect(chef_run).to configure_munchbox_base_apt_repo('munchbox')
      .with(uri: 'https://apt.munchbox.cc', distribution: 'stable')
  end

  # --- Underlying apt_repository gets added with our uri + suite ---
  it 'adds the apt_repository' do
    expect(chef_run).to add_apt_repository('munchbox')
      .with(uri: 'https://apt.munchbox.cc', distribution: 'stable')
  end

  # --- apt lock wait gates the apt-update + package installs ---
  it 'waits for the apt lock before touching apt' do
    expect(chef_run).to wait_munchbox_base_apt_lock_wait('munchbox_base_apt_repo')
  end
end
