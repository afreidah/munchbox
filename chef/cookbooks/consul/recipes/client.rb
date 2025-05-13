include_recipe 'consul::install'

template '/etc/consul.d/client.json' do
  source 'config.json.erb'
  variables(
    server: false,
    retry_join: node['consul']['servers']
  )
  notifies :restart, 'service[consul]', :delayed
end

service 'consul' do
  action [:enable, :start]
  only_if { node['init_package'] == 'systemd' }
end

