# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# rsyslog_rotation recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::rsyslog_rotation' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_rsyslog_rotation))
                        .converge('munchbox_base::rsyslog_rotation')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the rsyslog_rotation wrapping resource' do
    expect(chef_run).to configure_munchbox_base_rsyslog_rotation('baseline')
  end

  it 'ensures rsyslog is installed (brings in the syslog user/group + rsyslog-rotate)' do
    expect(chef_run).to install_package('rsyslog')
  end

  # --- Template lands with the right perms ---
  it 'renders the logrotate fragment 0644 root:root' do
    expect(chef_run).to create_template('/etc/logrotate.d/rsyslog')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  # --- Template body propagates the key attribute values ---
  it 'passes log_files, size, frequency, rotate, su_group through to the template' do
    tpl = chef_run.template('/etc/logrotate.d/rsyslog')
    expect(tpl.variables[:log_files]).to include('/var/log/syslog', '/var/log/auth.log')
    expect(tpl.variables[:rotate]).to eq(7)
    expect(tpl.variables[:frequency]).to eq('daily')
    expect(tpl.variables[:size]).to eq('200M')
    expect(tpl.variables[:su_group]).to eq('syslog')
  end

  # --- Force-rotate execute is declared :nothing and notified on template change ---
  it 'declares a :nothing logrotate -f execute' do
    expect(chef_run.execute('force-rotate /etc/logrotate.d/rsyslog'))
      .to do_nothing
  end

  it 'immediately notifies the force-rotate execute when the fragment changes' do
    tpl = chef_run.template('/etc/logrotate.d/rsyslog')
    expect(tpl).to notify('execute[force-rotate /etc/logrotate.d/rsyslog]').to(:run).immediately
  end
end
