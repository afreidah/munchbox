# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: docker
# Resource:: docker_configure
#
# Templates /etc/docker/daemon.json from structured properties + an
# escape-hatch `extra` Hash that's merged in for less-common keys.
# Restarts docker on change.
#
# Properties:
#   path           - Default /etc/docker/daemon.json.
#   dns            - Array of resolver IPs. nil to skip the key entirely.
#   dns_search     - Array, default ['.']. nil to skip.
#   log_driver     - Default 'json-file'.
#   log_max_file   - Default '3'.
#   log_max_size   - Default '10m'.
#   storage_driver - Default 'overlay2'. nil to skip.
#   live_restore   - Bool, default true. Keeps containers alive across
#                    dockerd restarts. nil to skip the key entirely.
#   extra          - Hash merged into the rendered daemon.json after
#                    structured keys. Last-write-wins; use for one-off
#                    knobs that don't deserve a property.
# -------------------------------------------------------------------------------

unified_mode true

provides :docker_configure

property :path,                String, default: '/etc/docker/daemon.json'
property :dns,                 [Array, NilClass]
property :dns_search,          [Array, NilClass],  default: ['.']
property :log_driver,          [String, NilClass], default: 'json-file'
property :log_max_file,        [String, NilClass], default: '3'
property :log_max_size,        [String, NilClass], default: '10m'
property :storage_driver,      [String, NilClass], default: 'overlay2'
property :insecure_registries, [Array, NilClass]
property :live_restore,        [TrueClass, FalseClass, NilClass], default: true
property :extra,               Hash, default: {}

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Render daemon.json, restart docker on change
# -------------------------------------------------------------------------------

action :configure do
  directory '/etc/docker' do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  # --- Build the Hash here, then JSON-render in the template. Keeps the template trivial. ---
  config = {}
  config['dns']            = new_resource.dns        unless new_resource.dns.nil?
  config['dns-search']     = new_resource.dns_search unless new_resource.dns_search.nil?
  unless new_resource.log_driver.nil?
    config['log-driver']   = new_resource.log_driver
    config['log-opts']     = {
      'max-file' => new_resource.log_max_file,
      'max-size' => new_resource.log_max_size,
    }
  end
  config['storage-driver']      = new_resource.storage_driver      unless new_resource.storage_driver.nil?
  config['insecure-registries'] = new_resource.insecure_registries unless new_resource.insecure_registries.nil?
  config['live-restore']        = new_resource.live_restore        unless new_resource.live_restore.nil?
  config.merge!(new_resource.extra.to_hash)

  template new_resource.path do
    source 'daemon.json.erb'
    cookbook 'docker'
    owner 'root'
    group 'root'
    mode  '0644'
    variables(config: config)
    notifies :restart, 'service[docker]', :delayed
  end

  service 'docker' do
    action :nothing
  end
end
