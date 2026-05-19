# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Resource:: cinc_server_configure
#
# Templates /etc/opscode/chef-server.rb and runs `chef-server-ctl
# reconfigure` whenever the file changes. The reconfigure is a notify
# (no action :run) so it only fires on real config drift, not every
# converge.
#
# Properties:
#   api_fqdn - The fqdn the server advertises (required).
#   settings - Hash of `'directive[key]' => value-literal` pairs rendered
#              verbatim into chef-server.rb. Values must be valid ruby
#              literals (quote strings, etc.).
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_server_configure

property :api_fqdn, String, required: true
property :settings, Hash,   default: {}

default_action :configure

# --- Drop chef-server.rb, run reconfigure on change ---
action :configure do
  directory '/etc/opscode' do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  template '/etc/opscode/chef-server.rb' do
    source 'chef-server.rb.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(api_fqdn: new_resource.api_fqdn, settings: new_resource.settings)
    notifies :run, 'execute[chef-server-ctl reconfigure]', :immediately
  end

  execute 'chef-server-ctl reconfigure' do
    command 'chef-server-ctl reconfigure'
    # --- License accept is required since 14.x; harmless on older releases ---
    environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
    action :nothing
  end
end

# --- Remove the rendered config; do NOT auto-run reconfigure ---
action :remove do
  file '/etc/opscode/chef-server.rb' do
    action :delete
  end
end
