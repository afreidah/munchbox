#
# Cookbook:: consul
# Recipe:: install
#
# Installs Consul via HashiCorp’s official binary archive.

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
  owner 'consul'
  group 'consul'
  mode '0750'
  recursive true
end

# Create config directory
directory '/etc/consul.d' do
  owner 'consul'
  group 'consul'
  mode '0750'
  recursive true
end

