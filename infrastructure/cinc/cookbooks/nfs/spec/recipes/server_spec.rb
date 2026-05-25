# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# server recipe spec -- steps into nfs_server. Empty exports = no-op; with
# exports, renders /etc/exports + notifies exportfs -ra.
# -------------------------------------------------------------------------------

RSpec.describe 'nfs::server' do
  cached(:default_run) do
    ChefSpec::SoloRunner.new(step_into: %w(nfs_server)).converge(described_recipe)
  end

  it 'declares the nfs_server resource' do
    expect(default_run).to configure_nfs_server('nfs-server')
      .with(
        package: 'nfs-kernel-server',
        exports_path: '/etc/exports',
        service_name: 'nfs-server'
      )
  end

  it 'is a no-op when exports is empty (the default)' do
    # --- early return skips package/file/service/execute resources entirely ---
    expect(default_run.find_resources(:apt_package)).to be_empty
    expect(default_run.find_resources(:file).map(&:name)).not_to include('/etc/exports')
    expect(default_run.find_resources(:service)).to be_empty
  end

  context 'with exports populated via attributes' do
    cached(:exports_run) do
      ChefSpec::SoloRunner.new(step_into: %w(nfs_server)) do |node|
        node.normal['nfs']['server']['exports'] = [
          { 'path' => '/srv/nfs/test', 'clients' => '127.0.0.0/8',
            'options' => 'rw,sync,no_subtree_check,no_root_squash' },
        ]
      end.converge(described_recipe)
    end

    it 'installs nfs-kernel-server' do
      expect(exports_run).to install_apt_package('nfs-kernel-server')
    end

    it 'renders /etc/exports root:root 0644 with the managed-block header + entry' do
      expect(exports_run).to create_file('/etc/exports')
        .with(owner: 'root', group: 'root', mode: '0644')
      rendered = exports_run.file('/etc/exports').content
      expect(rendered).to match(/managed by chef/)
      expect(rendered).to include('/srv/nfs/test 127.0.0.0/8(rw,sync,no_subtree_check,no_root_squash)')
    end

    it 'notifies exportfs -ra (delayed) when /etc/exports changes' do
      expect(exports_run.file('/etc/exports'))
        .to notify('execute[exportfs -ra]').to(:run).delayed
    end

    it 'declares the exportfs execute as :nothing (only fires on notify)' do
      expect(exports_run.execute('exportfs -ra')).to do_nothing
    end

    it 'enables + starts nfs-server' do
      expect(exports_run).to enable_service('nfs-server')
      expect(exports_run).to start_service('nfs-server')
    end
  end
end
