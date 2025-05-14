include_recipe 'firewall'

# Manage the systemd service
service 'consul' do
  provider Chef::Provider::Service::Systemd
  supports restart: true, status: true
  action   [:enable, :start]
  subscribes :restart, 'template[/etc/consul.d/server.json]', :immediately
end
