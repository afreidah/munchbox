# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# packages recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::packages' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_packages)) do |node|
      node.override['munchbox_base']['packages'] = %w(curl jq vim)
    end.converge('munchbox_base::packages')
  end

  # --- Wrapping resource gets credit for coverage + carries the package list ---
  it 'declares the baseline packages resource with the configured list' do
    expect(chef_run).to install_munchbox_base_packages('baseline')
      .with(packages: %w(curl jq vim))
  end

  # --- Underlying package resource installs every requested package ---
  it 'installs every requested package' do
    expect(chef_run).to install_package('baseline')
      .with(package_name: %w(curl jq vim))
  end

  it 'purges the recipe-level purge list (default empty -> resource declared no-op)' do
    # --- recipe declares apt_package 'munchbox_base purge list' unconditionally; default purge list is empty ---
    expect(chef_run).to purge_apt_package('munchbox_base purge list')
  end
end
