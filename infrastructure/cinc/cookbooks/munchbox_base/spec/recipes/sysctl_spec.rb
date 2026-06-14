# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# sysctl recipe spec -- step into munchbox_base_sysctl to cover the
# file write + sysctl reload execute.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::sysctl' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_sysctl)).converge(described_recipe)
  end

  it 'declares the munchbox_base_sysctl wrapping resource' do
    expect(chef_run).to configure_munchbox_base_sysctl('baseline')
      .with(path: '/etc/sysctl.d/99-munchbox.conf')
  end

  it 'writes /etc/sysctl.d/99-munchbox.conf root:root 0644 with the cluster-wide knobs' do
    expect(chef_run).to create_file('/etc/sysctl.d/99-munchbox.conf')
      .with(owner: 'root', group: 'root', mode: '0644')
    rendered = chef_run.file('/etc/sysctl.d/99-munchbox.conf').content
    expect(rendered).to match(/^vm\.overcommit_memory\s*=\s*1$/)
    # --- ingress dnsdist binds the floating DNS VIP on the standby node ---
    expect(rendered).to match(/^net\.ipv4\.ip_nonlocal_bind\s*=\s*1$/)
  end

  it 'declares the reload-sysctl execute as :nothing (only fires on notify)' do
    expect(chef_run.execute('reload munchbox sysctl')).to do_nothing
  end

  it 'notifies the reload-sysctl execute immediately when the file changes' do
    expect(chef_run.file('/etc/sysctl.d/99-munchbox.conf'))
      .to notify('execute[reload munchbox sysctl]').to(:run).immediately
  end
end
