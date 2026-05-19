# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec -- step into the wrapping resource so we cover the
# underlying template + execute it declares.
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_server::configure' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_server_configure)).converge('cinc_server::configure')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the cinc_server_configure resource' do
    expect(chef_run).to configure_cinc_server_configure('cinc-server')
  end

  # --- chef-server.rb is templated with correct perms ---
  it 'templates /etc/opscode/chef-server.rb' do
    expect(chef_run).to create_template('/etc/opscode/chef-server.rb')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  # --- reconfigure is :nothing until the template notifies it ---
  it 'declares chef-server-ctl reconfigure as a notify-only execute' do
    expect(chef_run.execute('chef-server-ctl reconfigure')).to do_nothing
  end

  # --- Template change should fire an immediate reconfigure ---
  it 'queues an immediate reconfigure when chef-server.rb changes' do
    template = chef_run.template('/etc/opscode/chef-server.rb')
    expect(template).to notify('execute[chef-server-ctl reconfigure]').to(:run).immediately
  end
end
