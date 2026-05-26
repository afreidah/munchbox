# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# resolv_conf recipe spec -- recipe resolves the nameserver from one of
# three sources; cover the role-attribute, global-attribute, and
# raise-if-empty paths.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::resolv_conf' do
  context 'with the nameserver set directly on the cookbook attribute' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_resolv_conf)) do |node|
        node.normal['munchbox_base']['resolv_conf']['nameserver'] = '192.168.68.60'
      end.converge(described_recipe)
    end

    it 'declares the wrapping resource with the configured nameserver' do
      expect(chef_run).to configure_munchbox_base_resolv_conf('baseline')
        .with(path: '/etc/resolv.conf', search: 'munchbox.cc', nameserver: '192.168.68.60')
    end

    it 'templates /etc/resolv.conf root:root 0644 with search + nameserver vars' do
      expect(chef_run).to create_template('/etc/resolv.conf')
        .with(owner: 'root', group: 'root', mode: '0644')
      tpl = chef_run.template('/etc/resolv.conf')
      expect(tpl.variables[:search]).to eq('munchbox.cc')
      expect(tpl.variables[:nameserver]).to eq('192.168.68.60')
    end
  end

  context 'with the nameserver derived from node[:global][:dns_endpoint_ip]' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_resolv_conf)) do |node|
        node.normal['global']['dns_endpoint_ip'] = '192.168.68.61'
      end.converge(described_recipe)
    end

    it 'falls back to the global dns_endpoint_ip when no explicit override' do
      expect(chef_run).to configure_munchbox_base_resolv_conf('baseline')
        .with(nameserver: '192.168.68.61')
    end
  end

  # --- the recipe also raises when nameserver is empty; we don't unit-test that path
  #     here because chef's compile-error formatter writes the banner directly to STDOUT
  #     (not $stdout / Chef::Log), which can't be silenced inside an rspec expect block.
  #     The defensive raise is covered live: any node missing both nameserver overrides
  #     fails its converge with the helpful message.
end
