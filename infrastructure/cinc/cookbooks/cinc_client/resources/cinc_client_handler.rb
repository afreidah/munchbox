# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Resource:: cinc_client_handler
#
# Installs the Alertmanager exception handler and registers it from
# /etc/cinc/client.d, so a failed converge reports itself with the exception
# that caused it. The handler class ships as a cookbook_file and the drop-in
# that registers it is templated with the endpoint and the expiry window.
#
# Properties:
#   endpoint - Alertmanager base URL the handler posts to (required).
#   window   - Seconds until the alert expires; must outlast the gap between
#              runs or the alert flaps between them.
#   severity - Label attached to the posted alert.
#   timeout  - Open and read timeout for the post, in seconds.
#   path     - Directory the handler class is installed into.
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_client_handler

property :endpoint, String, required: true
property :window,   Integer, default: 7200
property :severity, String,  default: 'warning'
property :timeout,  Integer, default: 5
property :path,     String,  default: '/var/cinc/handlers'

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Ship the handler class, then the drop-in that loads it
# -------------------------------------------------------------------------------

action :install do
  directory new_resource.path do
    owner 'root'
    group 'root'
    mode  '0755'
    recursive true
  end

  cookbook_file "#{new_resource.path}/alertmanager_handler.rb" do
    source 'alertmanager_handler.rb'
    cookbook 'cinc_client'
    owner 'root'
    group 'root'
    mode  '0644'
  end

  directory '/etc/cinc/client.d' do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  template '/etc/cinc/client.d/alertmanager.rb' do
    source 'handler.rb.erb'
    cookbook 'cinc_client'
    owner 'root'
    group 'root'
    mode  '0644'
    variables(
      handler_path: "#{new_resource.path}/alertmanager_handler.rb",
      endpoint: new_resource.endpoint,
      window: new_resource.window,
      severity: new_resource.severity,
      timeout: new_resource.timeout
    )
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Drop the registration first so nothing loads a missing file
# -------------------------------------------------------------------------------

action :remove do
  file '/etc/cinc/client.d/alertmanager.rb' do
    action :delete
  end

  file "#{new_resource.path}/alertmanager_handler.rb" do
    action :delete
  end
end
