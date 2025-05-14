include_recipe 'consul::install'

# Make sure /etc/consul.d is owned by the consul user
directory node['consul']['config_dir'] do
  owner  node['consul']['service_user']
  group  node['consul']['service_group']
  mode   '0755'
end

# Render the JSON config (including disable_ipv6 + addresses.http)
template ::File.join(node['consul']['config_dir'], 'server.json') do
  source 'config.json.erb'
  owner  'root'
  group  'root'
  mode   '0644'
  variables(
    data_dir:         node['consul']['data_dir'],
    bind_addr:        node['consul']['bind_addr'],
    retry_join:       node['consul']['servers'],
    bootstrap_expect: node['consul']['bootstrap_expect'],
  )
  notifies :restart, 'service[consul]', :immediately
end

service 'consul.service' do
  action [:enable, :start, :restart]
  only_if { node['init_package'] == 'systemd' }
end
