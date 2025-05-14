#
# Cookbook:: consul
# Recipe:: install
#
# Installs Consul via HashiCorp’s official binary archive.


include_recipe 'consul::firewall'


version = node['consul']['version']
install_method = node['consul']['install_method'] # 'binary'

case install_method
when 'binary'
  archive_url = "https://releases.hashicorp.com/consul/#{version}/consul_#{version}_linux_arm64.zip"
  archive_path = ::File.join(Chef::Config[:file_cache_path], "consul_#{version}.zip")

  remote_file archive_path do
    source archive_url
    checksum node['consul']['checksum'] if node['consul'].key?('checksum')
    action :create
  end

  directory '/usr/local/bin' do
    mode '0755'
    recursive true
  end

  execute 'unzip_consul' do
    command "unzip -o #{archive_path} -d /usr/local/bin/"
    not_if { ::File.exist?('/usr/local/bin/consul') && `consul version`.include?(version) }
  end

  file '/usr/local/bin/consul' do
    mode '0755'
  end

when 'package'
  # if you wanted to use apt or yum, you could add the repo here
  include_recipe 'apt' if platform_family?('debian')
  package 'consul' do
    version version
    action :install
  end
else
  Chef::Log.error("Unknown consul install_method '#{install_method}'")
end

# Create a dedicated Consul user & group
group 'consul' do
  system true
  action :create
end

user 'consul' do
  system true
  gid 'consul'
  home '/var/lib/consul'
  shell '/bin/false'
  action :create
end

# Create Consul data directory
directory node['consul']['data_dir'] || '/var/lib/consul' do
  owner node['consul']['user']
  group node['consul']['group']
  mode '0750'
  recursive true
end

# Create config directory
directory '/etc/consul.d' do
  owner node['consul']['user']
  group node['consul']['group']
  mode '0750'
  recursive true
end

# Reload systemd when the unit file changes
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Render the consul.service unit
template '/etc/systemd/system/consul.service' do
  source 'consul.service.erb'
  owner node['consul']['user']
  group node['consul']['group']
  mode '0644'
  variables(
    install_dir:     node['consul']['install_dir'],
    config_dir:      node['consul']['config_dir'],
    data_dir:        node['consul']['data_dir'],
    service_user:    node['consul']['user'],
    service_group:   node['consul']['group'],
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

# Enable & start the consul service
service 'consul' do
  provider Chef::Provider::Service::Systemd
  action [:enable, :start]
  subscribes :restart, 'template[/etc/systemd/system/consul.service]', :immediately
end
