# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# bootstrap recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_server::bootstrap' do
  # --- Resource not_if guards shell out to chef-server-ctl; stub them so chefspec doesn't try to run them ---
  before do
    stub_command("chef-server-ctl org-show 'munchbox'").and_return(false)
    stub_command("chef-server-ctl user-show 'alex'").and_return(false)
    stub_command("chef-server-ctl org-user-list 'munchbox' | grep -qx 'alex'").and_return(false)
  end

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_server_org cinc_server_user)).converge('cinc_server::bootstrap')
  end

  # --- Declares the org wrapping resource with the configured names ---
  it 'declares the munchbox org' do
    expect(chef_run).to create_cinc_server_org('munchbox')
      .with(full_name: 'Munchbox')
  end

  # --- Declares the admin user wrapping resource and ties it to the org ---
  it 'declares the alex admin user tied to the munchbox org' do
    expect(chef_run).to create_cinc_server_user('alex')
      .with(
        first_name: 'Alex',
        last_name:  'Freidah',
        email:      'alex.freidah@gmail.com',
        org:        'munchbox'
      )
  end

  # --- /etc/cinc-bootstrap dir is created before user-create writes the pem there ---
  it 'creates the bootstrap key directory with restrictive perms' do
    expect(chef_run).to create_directory('/etc/cinc-bootstrap')
      .with(owner: 'root', group: 'root', mode: '0700')
  end
end
