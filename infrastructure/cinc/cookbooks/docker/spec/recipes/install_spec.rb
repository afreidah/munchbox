# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers the apt suite + the nomad group add. The real .deb fetch + arch
# detection get exercised by kitchen against a debian-12 VM.
# -------------------------------------------------------------------------------

RSpec.describe 'docker::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(docker_install)) do |node|
      node.automatic[:lsb][:codename]   = 'bookworm'
      node.automatic[:kernel][:machine] = 'aarch64'
      node.automatic[:platform]         = 'debian'
    end.converge('docker::install')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the docker_install wrapping resource' do
    expect(chef_run).to install_docker_install('docker')
  end

  # --- prereq packages installed (multi-name resource lookup happens by the array) ---
  it 'installs the prereq apt suite' do
    expect(chef_run).to install_apt_package(%w(apt-transport-https ca-certificates curl gnupg lsb-release))
  end

  # --- Conflicting docker-buildx is removed (ignored if absent) ---
  it 'removes docker-buildx so the upstream repo plugin can install cleanly' do
    expect(chef_run).to remove_apt_package(['docker-buildx'])
  end

  # --- apt_repository picks /linux/debian for debian platform ---
  it 'adds the docker apt repo with arm64 arch + bookworm + the debian repo path + key URL' do
    repo = chef_run.apt_repository('docker')
    expect(repo.arch).to eq('arm64')
    expect(repo.distribution).to eq('bookworm')
    expect(repo.uri).to eq('https://download.docker.com/linux/debian')
    expect(repo.components).to eq(['stable'])
    expect(repo.key).to eq(['https://download.docker.com/linux/debian/gpg'])
  end

  # --- docker-ce + companions installed ---
  it 'installs the docker-ce package suite' do
    expect(chef_run).to install_apt_package(%w(docker-ce docker-ce-cli containerd.io docker-compose-plugin))
  end

  # --- docker.service enabled + started ---
  it 'enables and starts docker.service' do
    expect(chef_run).to enable_service('docker')
    expect(chef_run).to start_service('docker')
  end

  # --- nomad is added to the docker group by default ---
  it 'appends nomad to the docker group' do
    expect(chef_run).to create_group('docker').with(append: true, members: ['nomad'])
  end

  # --- Dependent service is declared :nothing; the group notifies it only on actual change ---
  it 'declares the dependent service (nomad) as :nothing' do
    expect(chef_run.service('nomad')).to do_nothing
  end

  it 'notifies nomad restart only when the docker group changes' do
    expect(chef_run.group('docker'))
      .to notify('service[nomad]').to(:restart).delayed
  end
end

# -------------------------------------------------------------------------------
# dependent_service=nil escape hatch (used by kitchen suite)
# -------------------------------------------------------------------------------

RSpec.describe 'docker::install with dependent_service=nil' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(docker_install)) do |node|
      node.automatic[:lsb][:codename]   = 'bookworm'
      node.automatic[:kernel][:machine] = 'aarch64'
      node.automatic[:platform]         = 'debian'
      node.override[:docker][:install][:dependent_service] = nil
    end.converge('docker::install')
  end

  it 'still creates the docker group with nomad as a member' do
    expect(chef_run).to create_group('docker').with(members: ['nomad'])
  end

  it 'does not declare any dependent service to notify' do
    expect(chef_run.find_resource(:service, 'nomad')).to be_nil
  end
end

# -------------------------------------------------------------------------------
# amd64 detection path
# -------------------------------------------------------------------------------

RSpec.describe 'docker::install on amd64' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(docker_install)) do |node|
      node.automatic[:lsb][:codename]   = 'bookworm'
      node.automatic[:kernel][:machine] = 'x86_64'
      node.automatic[:platform]         = 'debian'
    end.converge('docker::install')
  end

  it 'adds the docker apt repo with amd64 arch on x86_64 boxes' do
    expect(chef_run.apt_repository('docker').arch).to eq('amd64')
  end
end

# -------------------------------------------------------------------------------
# Ubuntu detection path -- separate URL tree from debian
# -------------------------------------------------------------------------------

RSpec.describe 'docker::install on ubuntu noble' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(docker_install)) do |node|
      node.automatic[:lsb][:codename]   = 'noble'
      node.automatic[:kernel][:machine] = 'aarch64'
      node.automatic[:platform]         = 'ubuntu'
    end.converge('docker::install')
  end

  it 'uses the /linux/ubuntu apt path on ubuntu (not /linux/debian)' do
    repo = chef_run.apt_repository('docker')
    expect(repo.uri).to eq('https://download.docker.com/linux/ubuntu')
    expect(repo.distribution).to eq('noble')
    expect(repo.key).to eq(['https://download.docker.com/linux/ubuntu/gpg'])
  end
end
