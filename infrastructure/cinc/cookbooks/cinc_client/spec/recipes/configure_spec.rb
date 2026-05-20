# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::configure' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(cinc_client_configure)).converge('cinc_client::configure')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the cinc_client_configure resource' do
    expect(chef_run).to configure_cinc_client_configure('cinc')
  end

  # --- Config + cert + log dirs land with the right perms ---
  it 'creates /etc/cinc with 0755 root:root' do
    expect(chef_run).to create_directory('/etc/cinc')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  it 'creates /etc/cinc/trusted_certs with 0755 root:root' do
    expect(chef_run).to create_directory('/etc/cinc/trusted_certs')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  it 'creates the cinc log dir' do
    expect(chef_run).to create_directory('/var/log/cinc')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  # --- client.rb is templated with the cinc-server FQDN URL ---
  it 'templates /etc/cinc/client.rb' do
    expect(chef_run).to create_template('/etc/cinc/client.rb')
      .with(owner: 'root', group: 'root', mode: '0644')
  end

  it 'renders client.rb with the configured chef_server_url' do
    template = chef_run.template('/etc/cinc/client.rb')
    expect(template.variables[:chef_server_url])
      .to eq('https://cinc-server.munchbox.cc/organizations/munchbox')
  end

  # --- trusted_cert + validator_pem are conditional on attribute values ---
  context 'when no trusted_cert is provided' do
    it 'does not drop a cinc-server.crt' do
      expect(chef_run.find_resource(:file, '/etc/cinc/trusted_certs/cinc-server.crt')).to be_nil
    end
  end

  context 'when no validator_pem is provided' do
    it 'does not drop a validation.pem' do
      expect(chef_run.find_resource(:file, '/etc/cinc/validation.pem')).to be_nil
    end
  end

  context 'when trusted_cert + validator_pem are provided' do
    cached(:chef_run_with_creds) do
      ChefSpec::SoloRunner.new(step_into: %w(cinc_client_configure)) do |node|
        node.override[:cinc_client][:config][:trusted_cert]  = '-- TEST CERT --'
        node.override[:cinc_client][:config][:validator_pem] = '-- TEST VALIDATOR --'
      end.converge('cinc_client::configure')
    end

    it 'drops the cinc-server trusted cert with 0644 perms' do
      expect(chef_run_with_creds).to create_file('/etc/cinc/trusted_certs/cinc-server.crt')
        .with(owner: 'root', group: 'root', mode: '0644')
    end

    it 'drops the validator pem with 0600 perms (sensitive)' do
      expect(chef_run_with_creds).to create_file('/etc/cinc/validation.pem')
        .with(owner: 'root', group: 'root', mode: '0600')
    end
  end
end
