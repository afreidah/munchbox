# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Pi Bootstrap Cookbook - Docker Config Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Ensures Docker is configured to allow insecure registry for goren:5000.
# -------------------------------------------------------------------------------

# --- Ensure the Docker config directory exists
directory '/etc/docker' do
  owner 'root'
  group 'root'
  mode  '0755'
  recursive true
end

# --- Literal /etc/docker/daemon.json (no templating yet)
file '/etc/docker/daemon.json' do
  owner 'root'
  group 'root'
  mode  '0644'
  content <<~JSON
    {
      "insecure-registries": [
        "#{node['pi_bootstrap']['docker_registry_node']}:5000"
      ],
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "10m",
        "max-file": "5"
      }
    }
  JSON
  # Restart Docker if the file content changes
  notifies :restart, 'service[docker]', :delayed
end

# --- Docker service handle (restart only when notified)
service 'docker' do
  action :nothing
end

