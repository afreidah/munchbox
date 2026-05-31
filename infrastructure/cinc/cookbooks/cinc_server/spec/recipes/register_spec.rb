# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# register recipe spec
#
# Steps into the consul_service custom resource and asserts the rendered
# /etc/consul.d/cinc-server.json contains the expected service + check
# blocks. The reload is self-contained inside consul_service (execute
# resource subscribed to the JSON file, gated by only_if on the systemd
# unit) so the recipe converges in isolation without needing a fixture.
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_server::register' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(consul_service)).converge('cinc_server::register')
  end

  # --- Declares the custom resource at the recipe level ---
  it 'declares the consul_service resource for cinc-server' do
    expect(chef_run).to register_consul_service('cinc-server')
  end

  # --- Service-def JSON ownership + mode ---
  it 'writes /etc/consul.d/cinc-server.json owned by consul:consul mode 0640' do
    expect(chef_run).to create_file('/etc/consul.d/cinc-server.json')
      .with(owner: 'consul', group: 'consul', mode: '0640')
  end

  # --- Rendered JSON body matches the consul service-def schema ---
  it 'renders the expected service body in the JSON file' do
    json = chef_run.file('/etc/consul.d/cinc-server.json').content
    svc = JSON.parse(json).fetch('service')
    expect(svc['name']).to eq('cinc-server')
    expect(svc['port']).to eq(443)
    expect(svc['tags']).to include('chef', 'cinc', 'https')
    expect(svc.dig('check', 'http')).to eq('https://cinc-server.munchbox.cc/_status')
    expect(svc.dig('check', 'interval')).to eq('30s')
    expect(svc.dig('check', 'tls_skip_verify')).to eq(false)
  end

  # --- Reload execute exists in the resource collection (subscribed from the file side) ---
  it 'declares a reload execute and the JSON file notifies it on change' do
    exec = chef_run.find_resources(:execute).find { |r| r.name.start_with?('reload consul (consul_service:') }
    expect(exec).not_to be_nil
    ChefSpec::Coverage.cover!(exec)

    expect(chef_run.file('/etc/consul.d/cinc-server.json'))
      .to notify("execute[#{exec.name}]").to(:run).delayed
  end
end
