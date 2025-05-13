# Install Consul binary (using official HashiCorp repo or remote_file)
include_recipe 'consul::_install'

# Generate server config
template '/etc/consul.d/server.json' do
  source 'config.json.erb'
  variables(
    server: true,
    bootstrap_expect: node['consul']['servers'].size,
    retry_join: node['consul']['servers']
  )
  notifies :restart, 'service[consul]', :delayed
end

service 'consul' do
  action [:enable, :start]
end

