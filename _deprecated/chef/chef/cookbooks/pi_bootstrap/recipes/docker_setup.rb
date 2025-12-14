# -------------------------------------------------------------------------------
# Pi Bootstrap Cookbook - Docker Setup Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Ensures Docker is configured to allow insecure registry for mccoy:5000.
# -------------------------------------------------------------------------------

docker_daemon_config = '/etc/docker/daemon.json'

ruby_block 'add_insecure_registry' do
  block do
    require 'json'
    config = ::File.exist?(docker_daemon_config) ? JSON.parse(::File.read(docker_daemon_config)) : {}
    registries = config['insecure-registries'] || []
    unless registries.include?('mccoy:5000')
      registries << 'mccoy:5000'
      config['insecure-registries'] = registries
      ::File.write(docker_daemon_config, JSON.pretty_generate(config))
    end
  end
  notifies :restart, 'service[docker]', :immediately
end

service 'docker' do
  action :nothing
end
