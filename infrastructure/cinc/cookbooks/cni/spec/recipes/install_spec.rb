# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec -- steps into cni_install so the underlying
# directory/execute/file resources are covered.
# -------------------------------------------------------------------------------

RSpec.describe 'cni::install' do
  cached(:chef_run) do
    # --- pretend /opt/cni/bin/.cni-version is absent so the install path runs ---
    allow(::File).to receive(:exist?).and_call_original
    allow(::File).to receive(:exist?).with('/opt/cni/bin/.cni-version').and_return(false)
    allow(::File).to receive(:directory?).and_call_original
    allow(::File).to receive(:directory?).with('/opt/cni/bin').and_return(false)
    ChefSpec::SoloRunner.new(step_into: %w(cni_install)).converge(described_recipe)
  end

  it 'declares the cni_install resource' do
    expect(chef_run).to install_cni_install('baseline')
      .with(version: '1.4.0', install_dir: '/opt/cni/bin')
  end

  it 'creates /opt/cni/bin root:root 0755' do
    expect(chef_run).to create_directory('/opt/cni/bin')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  it 'downloads the plugins tarball for the active arch' do
    arch = (RbConfig::CONFIG['host_cpu'] == 'aarch64' ? 'arm64' : 'amd64')
    expect(chef_run).to run_execute('download cni plugins v1.4.0')
      .with(command: include("cni-plugins-linux-#{arch}-v1.4.0.tgz"))
  end

  it 'extracts the tarball into the install dir' do
    expect(chef_run).to run_execute('extract cni plugins v1.4.0')
      .with(command: include('tar -xzf'))
  end

  it 'writes the version stamp file' do
    expect(chef_run).to create_file('/opt/cni/bin/.cni-version')
      .with(content: "v1.4.0\n", owner: 'root', group: 'root', mode: '0644')
  end

  it 'cleans up the downloaded tarball' do
    arch = (RbConfig::CONFIG['host_cpu'] == 'aarch64' ? 'arm64' : 'amd64')
    expect(chef_run).to delete_file("/tmp/cni-plugins-linux-#{arch}-v1.4.0.tgz")
  end

  context 'when /opt/cni/bin/.cni-version already records the requested version' do
    cached(:idempotent_run) do
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/opt/cni/bin/.cni-version').and_return(true)
      allow(::File).to receive(:read).and_call_original
      allow(::File).to receive(:read).with('/opt/cni/bin/.cni-version').and_return("v1.4.0\n")
      allow(::File).to receive(:directory?).and_call_original
      allow(::File).to receive(:directory?).with('/opt/cni/bin').and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(cni_install)).converge(described_recipe)
    end

    it 'skips the download execute resource' do
      expect(idempotent_run.find_resources(:execute).map(&:name)).not_to include('download cni plugins v1.4.0')
    end

    it 'skips the extract execute resource' do
      expect(idempotent_run.find_resources(:execute).map(&:name)).not_to include('extract cni plugins v1.4.0')
    end
  end
end
