include_recipe 'consul::install'

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
  only_if { node['init_package'] == 'systemd' }
end

