# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: docker
# Recipe:: configure
#
# Templates /etc/docker/daemon.json. Gated by docker.daemon.enabled.
#
# DNS resolution for the `dns` key (in order):
#   1. docker.daemon.dns                  -- explicit override in the role
#   2. node['global']['dns_endpoint_ip']  -- per-node role-set shared value
#                                            (same source consul::dns reads)
#   3. nil                                -- daemon.json omits the key,
#                                            docker falls back to 8.8.8.8.
#                                            On oracle nodes that breaks
#                                            .consul resolution inside containers.
# -------------------------------------------------------------------------------

daemon = node[cookbook]['daemon']

return unless daemon['enabled']

# --- Derive at recipe time (per chef-style-guide: no derived attrs in attribute files). ---
dns = daemon['dns']
if dns.nil? && node['global'] && node['global']['dns_endpoint_ip']
  dns = [node['global']['dns_endpoint_ip']]
end

docker_configure 'daemon' do
  path                daemon['path']
  dns                 dns
  dns_search          daemon['dns_search']
  log_driver          daemon['log_driver']
  log_max_file        daemon['log_max_file']
  log_max_size        daemon['log_max_size']
  storage_driver      daemon['storage_driver']
  insecure_registries daemon['insecure_registries']
  live_restore        daemon['live_restore']
  extra               daemon['extra'].to_hash
end
