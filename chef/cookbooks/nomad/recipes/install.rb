#
# Cookbook:: nomad
# Recipe:: install
#
# Download & install the Nomad binary (or use the official HashiCorp repo)

include_recipe 'nomad::firewall'

remote_file 'nomad' do
  path        '/tmp/nomad.zip'
  source      "https://releases.hashicorp.com/nomad/#{node['nomad']['version']}/nomad_#{node['nomad']['version']}_linux_arm64.zip"
  notifies    :run, 'execute[unzip-nomad]', :immediately
end

directory '/etc/nomad.d' do
  owner node['nomad']['user']
  group node['nomad']['group']
  mode  '0755'
  action :create
end

execute 'unzip-nomad' do
  command 'unzip -o /tmp/nomad.zip -d /usr/local/bin'
  action  :nothing
end

directory node['nomad']['data_dir'] do
  owner node['nomad']['user']
  group node['nomad']['group']
  mode  '0755'
  recursive true
end

# Reload systemd when the unit file changes
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Render the nomad.service unit
template '/etc/systemd/system/nomad.service' do
  source 'nomad.service.erb'
  owner node['nomad']['user']
  group node['nomad']['group']
  mode '0644'
  variables(
    config_dir:      node['nomad']['config_dir'],
    data_dir:        node['nomad']['data_dir'],
    service_user:    node['nomad']['user'],
    service_group:   node['nomad']['group'],
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

# Enable & start the nomad service
service 'nomad' do
  provider Chef::Provider::Service::Systemd
  action [:enable, :start]
  subscribes :restart, 'template[/etc/systemd/system/nomad.service]', :immediately
end
