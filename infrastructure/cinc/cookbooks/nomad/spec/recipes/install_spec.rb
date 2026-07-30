# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers dir creation (root mode -> no user/group) + the hand-off to
# munchbox_lib_artifact (release-archive URL, SHA256SUMS verify url, zip
# extraction target) and the drift-only restart notify. The actual
# download / verify / unzip live in munchbox_lib_artifact (not stepped
# into here); kitchen verifies the real install end-to-end.
# -------------------------------------------------------------------------------

RSpec.describe 'nomad::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(nomad_install)).converge('nomad::install')
  end

  let(:artifact) { chef_run.find_resource('munchbox_lib_artifact', 'nomad 2.0.4') }

  # --- Resource declaration ---
  it 'declares the nomad_install resource' do
    expect(chef_run).to install_nomad_install('nomad')
  end

  # --- Default mode is User=root; no vestigial nomad user/group ---
  it 'does not create a nomad system group in the default (root) install mode' do
    expect(chef_run).to_not create_group('nomad')
  end

  it 'does not create a nomad system user in the default (root) install mode' do
    expect(chef_run).to_not create_user('nomad')
  end

  %w(/etc/nomad.d /var/lib/nomad /var/log/nomad).each do |dir|
    # --- 0750 root:root, mirroring ansible's defaults ---
    it "creates #{dir} with 0750 root:root" do
      expect(chef_run).to create_directory(dir)
        .with(owner: 'root', group: 'root', mode: '0750')
    end
  end

  # --- Hands off the download/verify/install to the shared artifact resource ---
  it 'delegates the install to munchbox_lib_artifact' do
    expect(chef_run).to install_munchbox_lib_artifact('nomad 2.0.4')
  end

  # --- HashiCorp release archive URL (amd64 on the default chefspec kernel) ---
  it 'builds the nomad release archive url' do
    expect(artifact.source).to eq('https://releases.hashicorp.com/nomad/2.0.4/nomad_2.0.4_linux_amd64.zip')
  end

  # --- Verifies against HashiCorp's published SHA256SUMS rather than a pinned sha ---
  it 'verifies against the published SHA256SUMS' do
    expect(artifact.sums_url).to eq('https://releases.hashicorp.com/nomad/2.0.4/nomad_2.0.4_SHA256SUMS')
  end

  # --- Extracts the zip into the binary's directory ---
  it 'installs the zip into /usr/local/bin' do
    expect(artifact.format).to eq(:zip)
    expect(artifact.bin_dir).to eq('/usr/local/bin')
  end

  # --- nomad is restarted ONLY when the artifact actually re-installed (drift) ---
  it 'restarts nomad only when the artifact re-installs (drift)' do
    expect(artifact).to notify('service[nomad]').to(:restart).delayed
  end

  # --- Shadow service is otherwise inert (the configure recipe owns enable/start) ---
  it 'declares the nomad service as do-nothing here' do
    expect(chef_run.service('nomad')).to do_nothing
  end
end
