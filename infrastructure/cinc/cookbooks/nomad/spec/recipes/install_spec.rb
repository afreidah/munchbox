# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers user/group/dir creation + the unzip package (the only system
# prereq). The actual `nomad version` check is shelled out and stubbed --
# kitchen verifies the real binary extraction end-to-end.
# -------------------------------------------------------------------------------

RSpec.describe 'nomad::install' do
  # --- not_if shell guards used by nomad_install (version-skew check); chefspec needs them stubbed ---
  before do
    stub_command(/nomad version/).and_return(false)
  end

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(nomad_install)).converge('nomad::install')
  end

  # --- Resource declaration ---
  it 'declares the nomad_install resource' do
    expect(chef_run).to install_nomad_install('nomad')
  end

  # --- Default mode is User=root; no vestigial nomad user should be created. ---
  it 'does not create a nomad system group in the default (root) install mode' do
    expect(chef_run).to_not create_group('nomad')
  end

  it 'does not create a nomad system user in the default (root) install mode' do
    expect(chef_run).to_not create_user('nomad')
  end

  %w(/etc/nomad.d /var/lib/nomad /var/log/nomad).each do |dir|
    # --- 0750 root:root, mirroring ansible's defaults. ---
    it "creates #{dir} with 0750 root:root" do
      expect(chef_run).to create_directory(dir)
        .with(owner: 'root', group: 'root', mode: '0750')
    end
  end

  # --- unzip is the only system-level prereq for extracting the release archive ---
  it 'installs unzip' do
    expect(chef_run).to install_package('unzip')
  end
end
