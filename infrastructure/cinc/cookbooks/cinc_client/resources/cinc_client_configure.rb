# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Resource:: cinc_client_configure
#
# Drops the on-disk state cinc-client needs to talk to a server:
#   - /etc/cinc/client.rb (rendered)
#   - /etc/cinc/trusted_certs/cinc-server.crt (if trusted_cert provided)
#   - /etc/cinc/validation.pem (if validator_pem provided; consumed + can be
#     hand-deleted after a successful first run)
#   - /var/log/cinc/ (log_location parent)
#
# Properties:
#   chef_server_url       - Full URL including /organizations/<org> (required).
#   node_name             - Override the node name; nil = cinc-client uses
#                           the system hostname (default).
#   log_level             - cinc log level symbol name (default 'info').
#   log_location          - Path for cinc-client.log (default /var/log/cinc/client.log).
#   validator_client_name - Org-level validator client name (required).
#   trusted_cert          - PEM content of the cinc-server CA cert (nil ok).
#   validator_pem         - PEM content of the org validator key (nil ok).
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_client_configure

property :chef_server_url,       String, required: true
property :node_name,             [String, nil]
property :log_level,             String,         default: 'info'
property :log_location,          String,         default: '/var/log/cinc/client.log'
property :validator_client_name, String,         required: true
property :trusted_cert,          [String, nil],  sensitive: true
property :validator_pem,         [String, nil],  sensitive: true

default_action :configure

# --- Render client.rb + drop trusted cert + (optional) validator pem ---
action :configure do
  directory '/etc/cinc' do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  directory '/etc/cinc/trusted_certs' do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  directory ::File.dirname(new_resource.log_location) do
    owner 'root'
    group 'root'
    mode  '0755'
    recursive true
  end

  if new_resource.trusted_cert
    file '/etc/cinc/trusted_certs/cinc-server.crt' do
      content new_resource.trusted_cert
      owner   'root'
      group   'root'
      mode    '0644'
    end
  end

  if new_resource.validator_pem
    file '/etc/cinc/validation.pem' do
      content   new_resource.validator_pem
      owner     'root'
      group     'root'
      mode      '0600'
      sensitive true
    end
  end

  template '/etc/cinc/client.rb' do
    source 'client.rb.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(
      chef_server_url: new_resource.chef_server_url,
      node_name: new_resource.node_name,
      log_level: new_resource.log_level,
      log_location: new_resource.log_location,
      validator_client_name: new_resource.validator_client_name
    )
  end
end

# --- Remove rendered config + cached state (does not unregister the node) ---
action :remove do
  %w(/etc/cinc/client.rb /etc/cinc/validation.pem /etc/cinc/client.pem /etc/cinc/trusted_certs/cinc-server.crt).each do |path|
    file path do
      action :delete
    end
  end
end
