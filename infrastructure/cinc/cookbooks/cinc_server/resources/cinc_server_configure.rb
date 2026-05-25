# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Resource:: cinc_server_configure
#
# Pins the system hostname to api_fqdn, mints a self-signed TLS cert that
# the cookbook owns end-to-end, points cinc-server's nginx at that cert
# (so we control CN + SAN without reaching into cinc-server's own files),
# templates /etc/opscode/chef-server.rb, and runs `chef-server-ctl
# reconfigure` whenever any of that changes.
#
# We do NOT depend on cinc-server's built-in self-signed cert generator.
# That generator is "create-once, leave alone" and ignores SAN/CN changes
# on subsequent reconfigures, which means api_fqdn changes never propagate
# to the served cert. Owning the cert ourselves fixes that and also lines
# up cleanly with a future Vault PKI integration -- the only thing that
# changes is where the cert comes from; the path + nginx wiring stay.
#
# Properties:
#   api_fqdn      - The fqdn the server advertises (required). Also drives
#                   the system hostname, the nginx server_name, and the
#                   cert CN.
#   ssl_alt_names - Extra SAN entries with `DNS:` or `IP:` prefixes. The
#                   api_fqdn is added automatically; this is for short
#                   hostnames, alternate fqdns, or IP SANs (default: []).
#   settings      - Hash of `'directive[key]' => value-literal` pairs rendered
#                   verbatim into chef-server.rb. Values must be valid ruby
#                   literals (quote strings, etc.).
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_server_configure

property :api_fqdn,      String, required: true
property :ssl_alt_names, Array,  default: []
property :settings,      Hash,   default: {}

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Pin hostname, own the cert, render chef-server.rb, run reconfigure on change
# -------------------------------------------------------------------------------

action :configure do
  # --- Hostname has to match api_fqdn so anything that defaults to the system hostname (nginx server_name, etc.) is right ---
  hostname new_resource.api_fqdn

  cert_dir  = '/etc/opscode/certs'
  cert_path = "#{cert_dir}/#{new_resource.api_fqdn}.crt"
  key_path  = "#{cert_dir}/#{new_resource.api_fqdn}.key"

  directory '/etc/opscode' do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  directory cert_dir do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  # --- Cookbook-owned self-signed cert. Idempotent on CN + SAN; regenerates only when either changes. ---
  san_entries = (["DNS:#{new_resource.api_fqdn}"] + new_resource.ssl_alt_names).uniq
  openssl_x509_certificate cert_path do
    common_name new_resource.api_fqdn
    extensions(
      'subjectAltName' => { 'values' => san_entries, 'critical' => false }
    )
    key_file   key_path
    key_length 2048
    expire     3650
    owner      'root'
    group      'root'
    mode       '0644'
    notifies :run, 'execute[chef-server-ctl reconfigure]', :delayed
  end

  file key_path do
    owner 'root'
    group 'root'
    mode  '0600'
    only_if { ::File.exist?(key_path) }
  end

  # --- Derive nginx settings: point at our cert + key, set server_name from api_fqdn ---
  nginx_derived = {
    "nginx['server_name']" => "'#{new_resource.api_fqdn}'",
    "nginx['ssl_certificate']" => "'#{cert_path}'",
    "nginx['ssl_certificate_key']" => "'#{key_path}'",
  }
  rendered_settings = new_resource.settings.merge(nginx_derived)

  template '/etc/opscode/chef-server.rb' do
    source 'chef-server.rb.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(api_fqdn: new_resource.api_fqdn, settings: rendered_settings)
    notifies :run, 'execute[chef-server-ctl reconfigure]', :immediately
  end

  execute 'chef-server-ctl reconfigure' do
    command 'chef-server-ctl reconfigure'
    # --- License accept is required since 14.x; harmless on older releases ---
    environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
    action :nothing
    notifies :run, 'execute[wait for cinc-server API ready]', :immediately
  end

  # --- Wait for /_status=pong so downstream chef-server-ctl calls don't race a half-up server. ---
  execute 'wait for cinc-server API ready' do
    command 'for i in $(seq 1 60); do curl -ksf https://localhost/_status | grep -q \'"status":"pong"\' && exit 0; sleep 2; done; exit 1'
    timeout 130
    action :nothing
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Remove the rendered config; do NOT auto-run reconfigure
# -------------------------------------------------------------------------------

action :remove do
  file '/etc/opscode/chef-server.rb' do
    action :delete
  end
end
