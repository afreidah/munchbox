# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers the per-platform/arch .deb URL (incl. the debian point-release ->
# major normalization), the pinned-checksum lookup, and the hand-off to
# munchbox_lib_artifact. The actual download/verify/dpkg live in
# munchbox_lib_artifact (not stepped into here); kitchen verifies end-to-end.
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::install on ubuntu noble arm64' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)) do |node|
      node.automatic[:platform]         = 'ubuntu'
      node.automatic[:platform_version] = '24.04'
      node.automatic[:kernel][:machine] = 'aarch64'
    end.converge('cinc_client::install')
  end

  let(:artifact) { chef_run.find_resource('munchbox_lib_artifact', 'cinc 19.3.14') }

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the cinc_client_install resource' do
    expect(chef_run).to install_cinc_client_install('cinc')
  end

  # --- Hands off to the shared artifact installer ---
  it 'delegates the install to munchbox_lib_artifact' do
    expect(chef_run).to install_munchbox_lib_artifact('cinc 19.3.14')
  end

  # --- Drops the stale packagecloud apt source ---
  it 'deletes the stale cinc-project apt source' do
    expect(chef_run).to delete_file('/etc/apt/sources.list.d/cinc-project.list')
  end

  # --- Hands the right ubuntu 24.04 arm64 .deb URL to the shared installer ---
  it 'builds the ubuntu 24.04 arm64 .deb url' do
    expect(artifact.source).to eq('https://packages.cinc.sh/files/stable/cinc/19.3.14/ubuntu/24.04/cinc_19.3.14-1_arm64.deb')
  end

  # --- Resolves the pinned sha256 for this platform/arch ---
  it 'passes the pinned ubuntu/24.04 arm64 checksum' do
    expect(artifact.checksum).to eq('afd790a8d80c74b21909914041547a65cea86b28c64c33a3c081960beb2f103d')
  end

  # --- Installs as a versioned .deb ---
  it 'installs the deb pinned to the matching version' do
    expect(artifact.format).to eq(:deb)
    expect(artifact.package_name).to eq('cinc')
    expect(artifact.package_version).to eq('19.3.14-1')
  end
end

RSpec.describe 'cinc_client::install on debian bookworm point release amd64' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)) do |node|
      node.automatic[:platform]         = 'debian'
      node.automatic[:platform_version] = '12.12'
      node.automatic[:kernel][:machine] = 'x86_64'
    end.converge('cinc_client::install')
  end

  let(:artifact) { chef_run.find_resource('munchbox_lib_artifact', 'cinc 19.3.14') }

  # --- Ohai reports 12.12 but cinc serves /debian/12/; the url must use major ---
  it 'normalizes the debian point release to the major version in the url' do
    expect(artifact.source).to eq('https://packages.cinc.sh/files/stable/cinc/19.3.14/debian/12/cinc_19.3.14-1_amd64.deb')
  end

  # --- Checksum lookup keys on the normalized debian/12, not debian/12.12 ---
  it 'resolves the debian/12 amd64 checksum despite the point-release platform_version' do
    expect(artifact.checksum).to eq('0faa6af94a6f4ac9c45a2435f130d8f08f54470bfabf91ef1c3ed266ca5ee70a')
  end
end

RSpec.describe 'cinc_client::install with channel + download_base overrides' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)) do |node|
      node.automatic[:platform]         = 'ubuntu'
      node.automatic[:platform_version] = '24.04'
      node.automatic[:kernel][:machine] = 'aarch64'
      node.override[:cinc_client][:install][:channel]       = 'current'
      node.override[:cinc_client][:install][:download_base] = 'https://mirror.internal/cinc'
    end.converge('cinc_client::install')
  end

  # --- Override flows into the url handed to munchbox_lib_artifact ---
  it 'uses the overridden channel + mirror base in the url' do
    artifact = chef_run.find_resource('munchbox_lib_artifact', 'cinc 19.3.14')
    expect(artifact.source).to eq('https://mirror.internal/cinc/current/cinc/19.3.14/ubuntu/24.04/cinc_19.3.14-1_arm64.deb')
  end
end

RSpec.describe 'cinc_client::install on a platform with no pinned checksum' do
  # --- fail closed: an unmapped platform/release must not install unverified ---
  it 'raises rather than installing without a recorded checksum' do
    expect do
      ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)) do |node|
        node.automatic[:platform]         = 'debian'
        node.automatic[:platform_version] = '11'
        node.automatic[:kernel][:machine] = 'x86_64'
      end.converge('cinc_client::install')
    end.to raise_error(%r{no pinned sha256 for debian/11})
  end
end
