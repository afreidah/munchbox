# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec -- steps into nvidia_install to cover the underlying
# file/apt_repository/apt_package resources.
# -------------------------------------------------------------------------------

RSpec.describe 'nvidia::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(nvidia_install)).converge(described_recipe)
  end

  it 'declares the nvidia_install resource' do
    expect(chef_run).to install_nvidia_install('baseline')
      .with(
        debian_nonfree_components: %w(main contrib non-free non-free-firmware),
        container_toolkit_repo_uri: 'https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH)',
        container_toolkit_key_url: 'https://nvidia.github.io/libnvidia-container/gpgkey',
        install_kernel_headers: true,
        packages: %w(nvidia-driver nvidia-container-toolkit)
      )
  end

  it 'writes the debian non-free sources.list with the running codename' do
    expect(chef_run).to create_file('/etc/apt/sources.list.d/debian-nonfree.list')
      .with(owner: 'root', group: 'root', mode: '0644')
    rendered = chef_run.file('/etc/apt/sources.list.d/debian-nonfree.list').content
    expect(rendered).to match(%r{^deb http://deb\.debian\.org/debian \w+ main contrib non-free non-free-firmware$})
  end

  it 'declares the deferred apt-get update execute (action :nothing)' do
    expect(chef_run.execute('apt-get update (debian-nonfree)')).to do_nothing
  end

  it 'notifies the apt-get update execute immediately when the sources file changes' do
    expect(chef_run.file('/etc/apt/sources.list.d/debian-nonfree.list'))
      .to notify('execute[apt-get update (debian-nonfree)]').to(:run).immediately
  end

  it 'adds the nvidia-container-toolkit apt repository' do
    expect(chef_run).to add_apt_repository('nvidia-container-toolkit')
      .with(
        uri: 'https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH)',
        distribution: '/',
        key: ['https://nvidia.github.io/libnvidia-container/gpgkey']
      )
  end

  it 'installs the linux-headers package matching the running kernel' do
    expect(chef_run).to install_apt_package("linux-headers-#{chef_run.node['kernel']['release']}")
  end

  it 'installs the nvidia driver + container toolkit packages' do
    expect(chef_run).to install_apt_package(%w(nvidia-driver nvidia-container-toolkit))
  end

  it 'waits for the apt lock around both the repo + package steps' do
    expect(chef_run).to wait_munchbox_base_apt_lock_wait('nvidia_install_repos')
    expect(chef_run).to wait_munchbox_base_apt_lock_wait('nvidia_install_packages')
  end

  context 'with install_kernel_headers disabled' do
    cached(:no_headers_run) do
      ChefSpec::SoloRunner.new(step_into: %w(nvidia_install)) do |node|
        node.normal['nvidia']['install']['install_kernel_headers'] = false
      end.converge(described_recipe)
    end

    it 'omits the linux-headers apt_package' do
      headers = "linux-headers-#{no_headers_run.node['kernel']['release']}"
      expect(no_headers_run.find_resources(:apt_package).map(&:name)).not_to include(headers)
    end
  end
end
