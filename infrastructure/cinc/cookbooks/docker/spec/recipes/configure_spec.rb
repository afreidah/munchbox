# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec
#
# Covers default render, dns=nil skip path, and the disable-via-attribute
# escape hatch.
# -------------------------------------------------------------------------------

RSpec.describe 'docker::configure' do
  context 'with explicit dns set in the role' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(docker_configure)) do |node|
        node.override[:docker][:daemon][:dns] = ['10.200.0.13']
      end.converge('docker::configure')
    end

    # --- Wrapping resource gets credit for coverage ---
    it 'declares the docker_configure wrapping resource' do
      expect(chef_run).to configure_docker_configure('daemon')
    end

    it 'creates /etc/docker (where daemon.json lives)' do
      expect(chef_run).to create_directory('/etc/docker')
    end

    # --- Template lands with the right perms ---
    it 'renders /etc/docker/daemon.json 0644 root:root' do
      expect(chef_run).to create_template('/etc/docker/daemon.json')
        .with(owner: 'root', group: 'root', mode: '0644')
    end

    # --- Recipe-built config Hash makes it into the template variables ---
    it 'passes the dns + log + storage keys into the template' do
      tpl = chef_run.template('/etc/docker/daemon.json')
      cfg = tpl.variables[:config]
      expect(cfg['dns']).to eq(['10.200.0.13'])
      # --- dns_search defaults to nil in attributes (recipe passes nil), so the resource skips the key entirely ---
      expect(cfg).not_to have_key('dns-search')
      expect(cfg['log-driver']).to eq('json-file')
      expect(cfg['log-opts']).to eq('max-file' => '3', 'max-size' => '10m')
      # --- storage_driver default intentionally not set in attributes (would break overlayfs nodes); recipe passes nil → resource skips ---
      expect(cfg).not_to have_key('storage-driver')
    end

    # --- daemon.json change triggers a docker restart ---
    it 'notifies a delayed docker restart on template change' do
      expect(chef_run.template('/etc/docker/daemon.json'))
        .to notify('service[docker]').to(:restart).delayed
    end
  end

  context 'without dns set (recipe defaults to nil)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(docker_configure)).converge('docker::configure')
    end

    it 'omits the dns key from the rendered config when nothing is set' do
      cfg = chef_run.template('/etc/docker/daemon.json').variables[:config]
      expect(cfg).to_not have_key('dns')
    end
  end

  context 'with docker.daemon.enabled=false' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(docker_configure)) do |node|
        node.override[:docker][:daemon][:enabled] = false
      end.converge('docker::configure')
    end

    it 'does not touch /etc/docker/daemon.json' do
      expect(chef_run).to_not create_template('/etc/docker/daemon.json')
    end
  end

  context "with node['global']['dns_endpoint_ip'] set (shared role-level attr)" do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(docker_configure)) do |node|
        node.override[:global][:dns_endpoint_ip] = '10.200.0.42'
      end.converge('docker::configure')
    end

    it 'uses the global dns_endpoint_ip when docker.daemon.dns is unset' do
      cfg = chef_run.template('/etc/docker/daemon.json').variables[:config]
      expect(cfg['dns']).to eq(['10.200.0.42'])
    end
  end

  context 'with explicit docker.daemon.dns over a global value (explicit wins)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(docker_configure)) do |node|
        node.override[:global][:dns_endpoint_ip] = '10.200.0.42'
        node.override[:docker][:daemon][:dns]    = ['10.200.0.99']
      end.converge('docker::configure')
    end

    it 'prefers the cookbook-namespace explicit override over the global default' do
      cfg = chef_run.template('/etc/docker/daemon.json').variables[:config]
      expect(cfg['dns']).to eq(['10.200.0.99'])
    end
  end

  context 'with extra keys merged in (escape hatch for one-off knobs)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(docker_configure)) do |node|
        node.override[:docker][:daemon][:extra] = { 'live-restore' => true }
      end.converge('docker::configure')
    end

    it 'merges the extra hash into the rendered config' do
      cfg = chef_run.template('/etc/docker/daemon.json').variables[:config]
      expect(cfg['live-restore']).to eq(true)
    end
  end
end
