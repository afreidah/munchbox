# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# disable_ipv6_ra recipe spec -- step into the resource to cover the
# sysctl file, the immediate sysctl-reload notify, and the RA-route flush.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::disable_ipv6_ra' do
  cached(:chef_run) do
    # --- only_if guard on the flush execute shells out; stub negative so we don't try to run ip ---
    stub_command('ip -6 route show proto ra | grep -q .').and_return(false)
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_disable_ipv6_ra)).converge(described_recipe)
  end

  it 'declares the wrapping resource' do
    expect(chef_run).to configure_munchbox_base_disable_ipv6_ra('baseline')
  end

  it 'writes the sysctl drop-in root:root 0644 with the all + default accept_ra knobs' do
    expect(chef_run).to create_file('/etc/sysctl.d/99-disable-ipv6-ra.conf')
      .with(owner: 'root', group: 'root', mode: '0644')
    rendered = chef_run.file('/etc/sysctl.d/99-disable-ipv6-ra.conf').content
    expect(rendered).to match(/^net\.ipv6\.conf\.all\.accept_ra\s*=\s*0$/)
    expect(rendered).to match(/^net\.ipv6\.conf\.default\.accept_ra\s*=\s*0$/)
  end

  it 'declares the reload-sysctl execute :nothing (only fires on notify)' do
    expect(chef_run.execute('reload sysctl ipv6 accept_ra')).to do_nothing
  end

  it 'notifies the reload execute immediately when the sysctl file changes' do
    expect(chef_run.file('/etc/sysctl.d/99-disable-ipv6-ra.conf'))
      .to notify('execute[reload sysctl ipv6 accept_ra]').to(:run).immediately
  end

  it 'declares the RA-route flush execute (only_if-gated to remain idempotent)' do
    # --- stubbed to return false above so the action shouldn't fire, but the resource is declared ---
    expect(chef_run.find_resources(:execute).map(&:name)).to include('flush ipv6 RA routes')
  end
end
