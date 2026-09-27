# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# handler recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::handler' do
  # --- Enabled is the shape the role converges; defaults leave it off ---
  context 'when enabled' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(cinc_client_handler)) do |node|
        node.override['cinc_client']['handler']['enabled'] = true
      end.converge('cinc_client::handler')
    end

    it 'declares the cinc_client_handler resource' do
      expect(chef_run).to install_cinc_client_handler('alertmanager')
    end

    it 'creates the handler directory' do
      expect(chef_run).to create_directory('/var/cinc/handlers')
        .with(owner: 'root', group: 'root', mode: '0755')
    end

    it 'ships the handler class' do
      expect(chef_run).to create_cookbook_file('/var/cinc/handlers/alertmanager_handler.rb')
        .with(owner: 'root', group: 'root', mode: '0644')
    end

    it 'creates the client.d drop-in directory' do
      expect(chef_run).to create_directory('/etc/cinc/client.d')
        .with(owner: 'root', group: 'root', mode: '0755')
    end

    it 'registers the handler from client.d' do
      expect(chef_run).to create_template('/etc/cinc/client.d/alertmanager.rb')
        .with(owner: 'root', group: 'root', mode: '0644')
    end

    # --- The drop-in has to name the file the cookbook_file installed ---
    it 'points the drop-in at the installed handler' do
      template = chef_run.template('/etc/cinc/client.d/alertmanager.rb')
      expect(template.variables[:handler_path]).to eq('/var/cinc/handlers/alertmanager_handler.rb')
    end

    it 'renders the configured endpoint' do
      template = chef_run.template('/etc/cinc/client.d/alertmanager.rb')
      expect(template.variables[:endpoint]).to eq('http://alertmanager.service.consul:9093')
    end

    # --- hourly + 30m randomized delay is a 90m worst case; the window must exceed it ---
    it 'expires the alert later than the longest gap between runs' do
      template = chef_run.template('/etc/cinc/client.d/alertmanager.rb')
      expect(template.variables[:window]).to be > 90 * 60
    end
  end

  # --- Disabling removes the drop-in rather than orphaning it ---
  context 'when disabled' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(cinc_client_handler)).converge('cinc_client::handler')
    end

    it 'removes the cinc_client_handler resource' do
      expect(chef_run).to remove_cinc_client_handler('alertmanager')
    end

    it 'deletes the client.d registration' do
      expect(chef_run).to delete_file('/etc/cinc/client.d/alertmanager.rb')
    end

    it 'deletes the handler class' do
      expect(chef_run).to delete_file('/var/cinc/handlers/alertmanager_handler.rb')
    end
  end
end
