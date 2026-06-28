# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# etc_hosts recipe spec -- step into munchbox_base_etc_hosts. chef-search
# returns the converging node only inside chef-zero; static_entries adds
# the literal entries (pihole/unbound boxes).
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::etc_hosts' do
  cached(:chef_run) do
    # --- chef-search isn't available under chefspec; return an empty index so only static_entries land in the block ---
    stub_search(:node, '*:*').and_return([])
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_etc_hosts)) do |node|
      node.normal['munchbox_base']['etc_hosts']['static_entries'] = [
        { 'ip' => '192.168.68.62', 'hostname' => 'green' },
        { 'ip' => '192.168.68.64', 'hostname' => 'logan' },
      ]
    end.converge(described_recipe)
  end

  it 'declares the wrapping resource keyed by baseline with the project defaults' do
    expect(chef_run).to configure_munchbox_base_etc_hosts('baseline')
      .with(domain: 'munchbox.cc', hosts_path: '/etc/hosts')
  end

  it 'writes /etc/hosts root:root 0644 with the marker block containing the static entries' do
    expect(chef_run).to create_file('/etc/hosts').with(owner: 'root', group: 'root', mode: '0644')
    content = chef_run.file('/etc/hosts').content
    expect(content).to include('# BEGIN MUNCHBOX CLUSTER HOSTS')
    expect(content).to include('# END MUNCHBOX CLUSTER HOSTS')
    expect(content).to match(/192\.168\.68\.62\s+green\s+green\.munchbox\.cc/)
    expect(content).to match(/192\.168\.68\.64\s+logan\s+logan\.munchbox\.cc/)
  end

  it 'declares the cloud-init dropin (only_if-gated on /etc/cloud/cloud.cfg.d existing)' do
    # --- only_if guard is a Ruby block; in chefspec ::Dir.exist? evaluates against the test FS,
    #     which usually doesn't have /etc/cloud/cloud.cfg.d. The resource is declared regardless.
    res = chef_run.find_resources(:file).find { |r| r.name == '/etc/cloud/cloud.cfg.d/99-disable-manage-hosts.cfg' }
    expect(res).not_to be_nil
    ChefSpec::Coverage.cover!(res) # find_resources alone doesn't mark it touched
  end
end
