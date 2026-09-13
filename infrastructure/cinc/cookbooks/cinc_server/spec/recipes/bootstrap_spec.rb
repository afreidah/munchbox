# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# bootstrap recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_server::bootstrap' do
  # --- Resource not_if guards shell out to chef-server-ctl; stub them so
  #     chefspec doesn't try to run them. Every user the recipe declares needs
  #     its own pair, so this grows with bootstrap['extra_users']. ---
  def stub_server_ctl
    stub_command("chef-server-ctl org-show 'munchbox'").and_return(false)
    %w(alex forgejo-ci).each do |user|
      stub_command("chef-server-ctl user-show '#{user}'").and_return(false)
      stub_command("chef-server-ctl user-show '#{user}' --with-orgs | grep -E '^organizations:' | grep -wq 'munchbox'").and_return(false)
    end
  end

  before do
    stub_server_ctl
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

  # -------------------------------------------------------------------------------
  # extra_users -- the CI identity Forgejo uploads cookbooks/roles/nodes with
  # -------------------------------------------------------------------------------

  it 'declares the forgejo-ci user tied to the munchbox org' do
    expect(chef_run).to create_cinc_server_user('forgejo-ci')
      .with(
        first_name: 'Forgejo',
        last_name: 'CI',
        email: 'forgejo-ci@munchbox.cc',
        org: 'munchbox'
      )
  end

  # --- A duplicate email is rejected by user-create, so this must not match the admin's ---
  it 'gives forgejo-ci an email distinct from the admin' do
    expect(chef_run.cinc_server_user('forgejo-ci').email)
      .not_to eq(chef_run.cinc_server_user('alex').email)
  end

  it 'sources the forgejo-ci password from its own vault path (stubbed)' do
    expect(chef_run.cinc_server_user('forgejo-ci').password).to eq('fake-vault-password')
  end

  it 'renders the forgejo-ci public key where chef-server-ctl reads it' do
    expect(chef_run).to create_file('/etc/cinc-bootstrap/forgejo-ci.pub')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  it 'sources the forgejo-ci public key from vault_fetch (stubbed)' do
    expect(chef_run.cinc_server_user('forgejo-ci').public_key).to eq('fake-vault-password')
  end

  it 'queues user-create and org-user-add for forgejo-ci' do
    expect(chef_run).to run_execute('chef-server-ctl user-create forgejo-ci')
    expect(chef_run).to run_execute('chef-server-ctl org-user-add munchbox forgejo-ci --admin')
  end

  # --- supplied key: the server mints nothing, so no pem lands on this host ---
  it 'creates forgejo-ci from the supplied public key' do
    expect(chef_run.execute('chef-server-ctl user-create forgejo-ci').command)
      .to include('--user-key', '/etc/cinc-bootstrap/forgejo-ci.pub', '--prevent-keygen')
  end

  it 'does not write a forgejo-ci private key' do
    expect(chef_run).not_to create_file('/etc/cinc-bootstrap/forgejo-ci.pem')
  end

  # --- captured key: the admin still lets the server generate its pair ---
  it 'lets the server generate the admin key' do
    expect(chef_run.execute('chef-server-ctl user-create alex').command)
      .to include('--filename', '/etc/cinc-bootstrap/alex.pem')
  end

  context 'with a user that sets neither key source' do
    it 'fails rather than creating a user with an unusable key' do
      expect do
        ChefSpec::SoloRunner.new(step_into: %w(cinc_server_org cinc_server_user)) do |node|
          node.normal['cinc_server']['bootstrap']['extra_users'] = [
            {
              'username' => 'forgejo-ci',
              'first_name' => 'Forgejo',
              'last_name' => 'CI',
              'email' => 'forgejo-ci@munchbox.cc',
              'password' => 'literal',
            },
          ]
        end.converge('cinc_server::bootstrap')
      end.to raise_error(Chef::Exceptions::ValidationFailed, /exactly one of/)
    end
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
