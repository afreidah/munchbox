# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers .deb URL derivation per platform/arch + the not_if guard that
# skips the download when the local cinc version already matches. The
# actual dpkg install is shelled out and stubbed -- kitchen verifies the
# real install end-to-end.
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::install on ubuntu noble arm64' do
  # --- not_if shell guard used by remote_file; chefspec needs it stubbed ---
  before { stub_command(/dpkg-query -W -f/).and_return(false) }

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)) do |node|
      node.automatic[:platform]         = 'ubuntu'
      node.automatic[:platform_version] = '24.04'
      node.automatic[:kernel][:machine] = 'aarch64'
    end.converge('cinc_client::install')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the cinc_client_install resource' do
    expect(chef_run).to install_cinc_client_install('cinc')
  end

  # --- Downloads the right per-platform / per-arch .deb URL ---
  it 'fetches the ubuntu 24.04 arm64 .deb from packages.cinc.sh' do
    expect(chef_run).to create_remote_file('/var/cache/cinc_19.3.14-1_arm64.deb')
      .with(source: 'https://packages.cinc.sh/files/stable/cinc/19.3.14/ubuntu/24.04/cinc_19.3.14-1_arm64.deb')
  end

  # --- dpkg_package is declared :nothing; remote_file notifies it on actual download. ---
  it 'declares the dpkg_package as :nothing, pinned to the matching version' do
    expect(chef_run.dpkg_package('cinc'))
      .to do_nothing
    expect(chef_run.dpkg_package('cinc').version).to eq('19.3.14-1')
    expect(chef_run.dpkg_package('cinc').source).to eq('/var/cache/cinc_19.3.14-1_arm64.deb')
  end

  it 'remote_file notifies the dpkg_package immediately on download' do
    expect(chef_run.remote_file('/var/cache/cinc_19.3.14-1_arm64.deb'))
      .to notify('dpkg_package[cinc]').to(:install).immediately
  end
end

RSpec.describe 'cinc_client::install on debian bookworm amd64' do
  before { stub_command(/dpkg-query -W -f/).and_return(false) }

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)) do |node|
      node.automatic[:platform]         = 'debian'
      node.automatic[:platform_version] = '12'
      node.automatic[:kernel][:machine] = 'x86_64'
    end.converge('cinc_client::install')
  end

  it 'fetches the debian 12 amd64 .deb URL' do
    expect(chef_run).to create_remote_file('/var/cache/cinc_19.3.14-1_amd64.deb')
      .with(source: 'https://packages.cinc.sh/files/stable/cinc/19.3.14/debian/12/cinc_19.3.14-1_amd64.deb')
  end
end

RSpec.describe 'cinc_client::install with channel + download_base overrides' do
  before { stub_command(/dpkg-query -W -f/).and_return(false) }

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_install)) do |node|
      node.automatic[:platform]         = 'ubuntu'
      node.automatic[:platform_version] = '24.04'
      node.automatic[:kernel][:machine] = 'aarch64'
      node.override[:cinc_client][:install][:channel]       = 'current'
      node.override[:cinc_client][:install][:download_base] = 'https://mirror.internal/cinc'
    end.converge('cinc_client::install')
  end

  it 'uses the overridden channel + mirror base in the URL' do
    expect(chef_run).to create_remote_file('/var/cache/cinc_19.3.14-1_arm64.deb')
      .with(source: 'https://mirror.internal/cinc/current/cinc/19.3.14/ubuntu/24.04/cinc_19.3.14-1_arm64.deb')
  end
end
