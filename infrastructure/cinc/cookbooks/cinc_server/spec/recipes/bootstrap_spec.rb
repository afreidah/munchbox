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
    stub_command("chef-server-ctl user-show 'alex' --with-orgs | grep -E '^organizations:' | grep -wq 'munchbox'").and_return(false)
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
        last_name: 'Freidah',
        email: 'alex.freidah@gmail.com',
        org: 'munchbox'
      )
  end

  it 'sources the admin password from vault_fetch (stubbed)' do
    # --- lazy{} resolves on property read; stub returns "fake-vault-password" ---
    expect(chef_run.cinc_server_user('alex').password).to eq('fake-vault-password')
  end

  context 'with an explicit password attribute override (break-glass)' do
    before do
      stub_command("chef-server-ctl org-show 'munchbox'").and_return(false)
      stub_command("chef-server-ctl user-show 'alex'").and_return(false)
      stub_command("chef-server-ctl user-show 'alex' --with-orgs | grep -E '^organizations:' | grep -wq 'munchbox'").and_return(false)
    end

    cached(:override_run) do
      ChefSpec::SoloRunner.new(step_into: %w(cinc_server_org cinc_server_user)) do |node|
        node.normal['cinc_server']['bootstrap']['user']['password'] = 'literal-override'
      end.converge('cinc_server::bootstrap')
    end

    it 'wins over the vault fetch when set' do
      expect(override_run.cinc_server_user('alex').password).to eq('literal-override')
    end
  end

  # --- /etc/cinc-bootstrap dir is created before user-create writes the pem there ---
  it 'creates the bootstrap key directory with restrictive perms' do
    expect(chef_run).to create_directory('/etc/cinc-bootstrap')
      .with(owner: 'root', group: 'root', mode: '0700')
  end

  # --- Underlying chef-server-ctl execute resources are queued ---
  it 'queues the org-create execute (gated by org-show)' do
    expect(chef_run).to run_execute('chef-server-ctl org-create munchbox')
  end

  it 'queues the user-create execute (gated by user-show)' do
    expect(chef_run).to run_execute('chef-server-ctl user-create alex')
  end

  it 'queues the org-user-add execute to make alex an admin of munchbox' do
    expect(chef_run).to run_execute('chef-server-ctl org-user-add munchbox alex --admin')
  end

  # --- Pretend the pem exists post-user-create so the perms-lockdown file resource runs ---
  context 'when the captured pem exists' do
    cached(:chef_run_with_pem) do
      stub_command("chef-server-ctl org-show 'munchbox'").and_return(false)
      stub_command("chef-server-ctl user-show 'alex'").and_return(false)
      stub_command("chef-server-ctl user-show 'alex' --with-orgs | grep -E '^organizations:' | grep -wq 'munchbox'").and_return(false)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/etc/cinc-bootstrap/alex.pem').and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(cinc_server_org cinc_server_user)).converge('cinc_server::bootstrap')
    end

    it 'locks the captured pem down to 0600 root:root' do
      expect(chef_run_with_pem).to create_file('/etc/cinc-bootstrap/alex.pem')
        .with(owner: 'root', group: 'root', mode: '0600')
    end
  end
end
