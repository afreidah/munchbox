include_recipe 'consul::install'

template '/etc/consul.d/client.json' do
  source 'client-config.json.erb'
  variables(
    server: false,
    retry_join: node['consul']['servers']
  )
  notifies :restart, 'service[consul]', :delayed
end

service 'consul.service' do
  action [:enable, :start, :restart]
  only_if { systemd? }
end
