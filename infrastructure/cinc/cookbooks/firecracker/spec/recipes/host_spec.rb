# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# host recipe spec -- steps into firecracker_host to cover the user, the thin
# pool's script and unit, and containerd's config.
# -------------------------------------------------------------------------------

RSpec.describe 'firecracker::host' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(firecracker_host)).converge(described_recipe)
  end

  it 'declares the firecracker_host resource from the attributes' do
    expect(chef_run).to configure_firecracker_host('firecracker')
      .with(pool_name: 'containerd-thinpool', data_size: '50G', meta_size: '1G', base_image_size: '10GB')
  end

  it 'makes Firecracker its system user and group at 990' do
    expect(chef_run).to create_group('firecracker').with(gid: 990, system: true)
    expect(chef_run).to create_user('firecracker')
      .with(uid: 990, gid: 990, system: true, shell: '/usr/sbin/nologin')
  end

  it 'installs dmsetup once the apt lock is free' do
    expect(chef_run).to wait_munchbox_base_apt_lock_wait('firecracker_host_install')
    expect(chef_run).to install_apt_package('dmsetup')
  end

  it 'keeps the pool files in a directory only root reads' do
    expect(chef_run).to create_directory('/var/lib/containerd-thinpool')
      .with(owner: 'root', group: 'root', mode: '0700')
  end

  it 'writes the script that brings the pool up at the attribute sizes' do
    script = chef_run.file('/usr/local/sbin/containerd-thinpool')
    expect(chef_run).to create_file('/usr/local/sbin/containerd-thinpool').with(mode: '0755')
    expect(script.content).to include('truncate -s 50G "${dir}/data"')
    expect(script.content).to include('truncate -s 1G "${dir}/meta"')
    expect(script.content).to include('dmsetup create "${pool}"')
    expect(script.content).to include('pool=containerd-thinpool')
  end

  it 'brings the pool up ahead of containerd without containerd needing it' do
    unit = chef_run.systemd_unit('containerd-thinpool.service')
    expect(chef_run).to create_systemd_unit('containerd-thinpool.service')
    expect(chef_run).to enable_systemd_unit('containerd-thinpool.service')
    expect(chef_run).to start_systemd_unit('containerd-thinpool.service')
    expect(unit.content).to include('Before=containerd.service')
    expect(unit.content).to include('WantedBy=containerd.service')
    expect(unit.content).not_to include('RequiredBy')
  end

  it 'gives containerd the devmapper snapshotter on the pool, CRI still off' do
    config = chef_run.file('/etc/containerd/config.toml').content
    expect(chef_run).to create_file('/etc/containerd/config.toml').with(owner: 'root', group: 'root', mode: '0644')
    expect(config).to include('version = 3')
    expect(config).to include('disabled_plugins = ["io.containerd.grpc.v1.cri"]')
    expect(config).to include('[plugins."io.containerd.snapshotter.v1.devmapper"]')
    expect(config).to include('pool_name = "containerd-thinpool"')
    expect(config).to include('base_image_size = "10GB"')
    expect(config).to include('fs_type = "ext4"')
  end

  it 'restarts containerd, and only when its config changes' do
    expect(chef_run.file('/etc/containerd/config.toml')).to notify('service[containerd]').to(:restart).delayed
    expect(chef_run).to nothing_service('containerd')
  end

  context 'with a bigger pool on another name' do
    cached(:sized_run) do
      ChefSpec::SoloRunner.new(step_into: %w(firecracker_host)) do |node|
        node.normal['firecracker']['host']['data_size'] = '80G'
        node.normal['firecracker']['host']['pool_name'] = 'vm-pool'
      end.converge(described_recipe)
    end

    it 'carries both into the script and the config' do
      expect(sized_run.file('/usr/local/sbin/containerd-thinpool').content).to include('truncate -s 80G')
      expect(sized_run.file('/etc/containerd/config.toml').content).to include('pool_name = "vm-pool"')
    end
  end
end
