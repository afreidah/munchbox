# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers user/group/dir creation + the hand-off to munchbox_lib_artifact
# (release-archive URL, SHA256SUMS verification url, zip extraction target)
# and the drift-only service restart subscribe. The actual download /
# verify / unzip live in munchbox_lib_artifact (not stepped into here);
# kitchen verifies the real install + executable binary end-to-end.
# -------------------------------------------------------------------------------

RSpec.describe 'consul::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(consul_install)).converge('consul::install')
  end

  let(:artifact) { chef_run.find_resource('munchbox_lib_artifact', 'consul 2.0.3') }

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

  # --- Hands off the download/verify/install to the shared artifact resource ---
  it 'delegates the install to munchbox_lib_artifact' do
    expect(chef_run).to install_munchbox_lib_artifact('consul 2.0.3')
  end

  # --- HashiCorp release archive URL (amd64 on the default chefspec kernel) ---
  it 'builds the consul release archive url' do
    expect(artifact.source).to eq('https://releases.hashicorp.com/consul/2.0.3/consul_2.0.3_linux_amd64.zip')
  end

  # --- Verifies against HashiCorp's published SHA256SUMS rather than a pinned sha ---
  it 'verifies against the published SHA256SUMS' do
    expect(artifact.sums_url).to eq('https://releases.hashicorp.com/consul/2.0.3/consul_2.0.3_SHA256SUMS')
  end

  # --- Extracts the zip into the binary's directory ---
  it 'installs the zip into /usr/local/bin' do
    expect(artifact.format).to eq(:zip)
    expect(artifact.bin_dir).to eq('/usr/local/bin')
  end

  # --- consul is restarted ONLY when the artifact actually re-installed (drift), never on a no-op converge ---
  it 'restarts consul only when the artifact re-installs (drift)' do
    expect(artifact).to notify('service[consul]').to(:restart).delayed
  end

  # --- The shadow service is otherwise inert (the configure recipe owns enable/start) ---
  it 'declares the consul service as do-nothing here' do
    expect(chef_run.service('consul')).to do_nothing
  end

  it 'creates the consul.service systemd unit' do
    expect(chef_run).to create_systemd_unit('consul.service')
  end
end
