# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: pi_bootstrap
# Recipe:: docker_insecure_registry
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Ensures Docker is configured to allow insecure registry for goren:5000.
# --------------------------------------------------------------------

file_path = '/etc/docker/daemon.json'
registry = node['pi_bootstrap']['docker_registry_node']

ruby_block 'update_insecure_registries' do
  block do
    require 'json'
    config = File.exist?(file_path) ? JSON.parse(File.read(file_path)) : {}
    config['insecure-registries'] ||= []
    unless config['insecure-registries'].include?("#{registry}:5000")
      config['insecure-registries'] << "#{registry}:5000"
      File.write(file_path, JSON.pretty_generate(config))
      node.run_context.resource_collection.find('service[docker]').run_action(:restart)
    end
  end
end

service 'docker' do
  action :nothing
end
