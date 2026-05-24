# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers user/group/dir creation + the unzip package (the only system
# prereq). Doesn't exercise the actual `consul version` check (chefspec
# can't stub the binary's stdout) -- that's verified in kitchen.
# -------------------------------------------------------------------------------

RSpec.describe 'consul::install' do
  # --- not_if shell guards used by consul_install (version-skew check); chefspec needs them stubbed since it can't really exec ---
  before do
    stub_command(/consul version/).and_return(false)
  end

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(consul_install)).converge('consul::install')
  end

  # --- Resource declaration ---
  it 'declares the consul_install resource' do
    expect(chef_run).to install_consul_install('consul')
  end

  # --- System group ---
  it 'creates the consul system group' do
    expect(chef_run).to create_group('consul').with(system: true)
  end

  # --- System user (no login, points home at the data dir) ---
  it 'creates the consul system user with /bin/false shell' do
    expect(chef_run).to create_user('consul')
      .with(group: 'consul', system: true, shell: '/bin/false')
  end

  %w(/etc/consul.d /opt/consul/data /etc/consul.d/tls /var/log/consul).each do |dir|
    # --- Standard dir layout, 0750 consul:consul (matches vault-cert-manager's perms) ---
    it "creates #{dir} with 0750 consul:consul" do
      expect(chef_run).to create_directory(dir)
        .with(owner: 'consul', group: 'consul', mode: '0750')
    end
  end

  # --- unzip is the only system-level prereq for extracting the release archive ---
  it 'installs unzip' do
    expect(chef_run).to install_package('unzip')
  end
end
