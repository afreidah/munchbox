# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Resource:: consul_service
#
# Registers a non-Nomad service with the local consul agent by rendering
# <config_dir>/<service_name>.json + SIGHUP-reloading consul. Use this
# for anything chef installs that isn't a Nomad workload (cinc-server,
# vault-server-side helpers, anything else outside the scheduler) so it
# shows up in the consul catalog + DNS like every other service.
#
# Nomad-managed services do NOT use this resource -- nomad registers them
# itself via its consul integration against the local agent's HTTP API.
#
# The reload is self-contained: an `execute systemctl reload consul`
# subscribed to the JSON file, gated by an `only_if` on the consul.service
# unit existing. That makes the resource a safe no-op on hosts that don't
# run consul (and during isolated chefspec runs) so callers don't need to
# guarantee service[consul] is in the same resource collection.
#
# Properties:
#   service_name - Service name as it appears in the catalog
#                  (default = resource name).
#   port         - Listening port (required).
#   address      - Service address; default omitted, agent uses its bind_addr.
#   tags         - Array of catalog tags.
#   meta         - Hash of free-form service metadata.
#   check        - Hash matching consul's service-check schema (http/tcp/
#                  script/grpc/...). Passed through verbatim.
#   config_dir   - default /etc/consul.d.
#   user/group   - JSON file owner (default consul/consul).
#   reload       - Run `systemctl reload consul` when the def changes
#                  (default true).
# -------------------------------------------------------------------------------

unified_mode true

provides :consul_service

property :service_name, String, name_property: true
property :port,         Integer, required: true
property :address,      [String, nil]
property :tags,         Array, default: []
property :meta,         Hash, default: {}
property :check,        [Hash, nil]
property :config_dir,   String, default: '/etc/consul.d'
property :user,         String, default: 'consul'
property :group,        String, default: 'consul'
property :reload,       [true, false], default: true

default_action :register

# -------------------------------------------------------------------------------
# Action :register  --  Render <config_dir>/<service_name>.json + reload consul
# -------------------------------------------------------------------------------

action :register do
  svc = {
    'name' => new_resource.service_name,
    'port' => new_resource.port,
  }
  svc['address'] = new_resource.address if new_resource.address
  svc['tags']    = new_resource.tags unless new_resource.tags.empty?
  svc['meta']    = new_resource.meta unless new_resource.meta.empty?
  svc['check']   = new_resource.check if new_resource.check

  json_path = "#{new_resource.config_dir}/#{new_resource.service_name}.json"

  file json_path do
    content "#{JSON.pretty_generate('service' => svc)}\n"
    owner   new_resource.user
    group   new_resource.group
    mode    '0640'
  end

  return unless new_resource.reload

  # --- Reload consul on def change. only_if on the systemd unit makes this a clean no-op when consul isn't installed yet (greenfield / chefspec). ---
  execute "reload consul (consul_service: #{new_resource.service_name})" do
    command 'systemctl reload consul'
    action :nothing
    subscribes :run, "file[#{json_path}]", :delayed
    only_if { ::File.exist?('/etc/systemd/system/consul.service') }
  end
end

# -------------------------------------------------------------------------------
# Action :deregister  --  Remove the JSON definition + reload consul
# -------------------------------------------------------------------------------

action :deregister do
  json_path = "#{new_resource.config_dir}/#{new_resource.service_name}.json"

  file json_path do
    action :delete
  end

  return unless new_resource.reload

  execute "reload consul (consul_service: #{new_resource.service_name} delete)" do
    command 'systemctl reload consul'
    action :nothing
    subscribes :run, "file[#{json_path}]", :delayed
    only_if { ::File.exist?('/etc/systemd/system/consul.service') }
  end
end
