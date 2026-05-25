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

  # --- Hostname is pinned to api_fqdn so the cert CN comes out right ---
  it 'sets the system hostname to api_fqdn' do
    expect(chef_run).to set_hostname('cinc-server.munchbox.cc')
  end

  # --- Template variables derive nginx server_name + point at our cookbook-owned cert ---
  it 'renders chef-server.rb with derived nginx settings' do
    template = chef_run.template('/etc/opscode/chef-server.rb')
    expect(template.variables[:settings]).to include(
      "nginx['server_name']" => "'cinc-server.munchbox.cc'",
      "nginx['ssl_certificate']" => "'/etc/opscode/certs/cinc-server.munchbox.cc.crt'",
      "nginx['ssl_certificate_key']" => "'/etc/opscode/certs/cinc-server.munchbox.cc.key'"
    )
  end

  # --- /etc/opscode is created with the right perms before the template lands in it ---
  it 'creates /etc/opscode with 0755 root:root' do
    expect(chef_run).to create_directory('/etc/opscode')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  # --- We own the cert end-to-end: dedicated dir + openssl_x509_certificate resource + key perms file ---
  it 'creates /etc/opscode/certs with 0755 root:root' do
    expect(chef_run).to create_directory('/etc/opscode/certs')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  it 'declares the self-signed cert with CN + SAN derived from api_fqdn' do
    expect(chef_run).to create_openssl_x509_certificate('/etc/opscode/certs/cinc-server.munchbox.cc.crt')
      .with(common_name: 'cinc-server.munchbox.cc')
  end

  it 'notifies a delayed reconfigure when the cert regenerates' do
    cert = chef_run.openssl_x509_certificate('/etc/opscode/certs/cinc-server.munchbox.cc.crt')
    expect(cert).to notify('execute[chef-server-ctl reconfigure]').to(:run).delayed
  end

  # --- API-readiness poll is notify-only; reconfigure fires it after a real config change ---
  it 'declares the wait-for-API execute as notify-only' do
    expect(chef_run.execute('wait for cinc-server API ready')).to do_nothing
  end

  it 'queues an immediate wait when reconfigure fires' do
    reconfigure = chef_run.execute('chef-server-ctl reconfigure')
    expect(reconfigure).to notify('execute[wait for cinc-server API ready]').to(:run).immediately
  end

  # --- Pretend the cert key exists post-cert-gen so the perms-lockdown file resource runs ---
  context 'when the cert key exists' do
    cached(:chef_run_with_key) do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/etc/opscode/certs/cinc-server.munchbox.cc.key').and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(cinc_server_configure)).converge('cinc_server::configure')
    end

    it 'locks the key down to 0600 root:root' do
      expect(chef_run_with_key).to create_file('/etc/opscode/certs/cinc-server.munchbox.cc.key')
        .with(owner: 'root', group: 'root', mode: '0600')
    end
  end
end
