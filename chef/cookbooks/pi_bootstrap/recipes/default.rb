#
# Cookbook:: pi_bootstrap
# Recipe:: default
#

ohai 'reload network attributes' do
  plugin 'network'
  action :nothing
end

# force that reload *at compile time*, so node['ipaddress'] is set
ruby_block 'reload Ohai network plugin at compile-time' do
  block do
    resources(ohai: 'reload network attributes').run_action(:reload)
  end
end

# now you can safely reference node['ipaddress']
ruby_block 'log my ipaddress' do
  block do
    ip = node['ipaddress']
    Chef::Log.info("My IP address is #{ip}")
  end
end

template '/etc/hostname' do
  source 'hostname.erb'
  variables(hostname: lazy { "#{node['pi_bootstrap']['hostname_prefix']}-#{node['ipaddress'].split('.').last}" })
  notifies :run, 'execute[hostnamectl-set]', :immediately
end

execute 'hostnamectl-set' do
  command lazy { "hostnamectl set-hostname #{node['pi_bootstrap']['hostname_prefix']}-#{node['ipaddress'].split('.').last}"} 
  action :nothing
end

ruby_block 'update_etc_hosts' do
  block do
    hosts = ::File.read('/etc/hosts').lines.reject { |l| l =~ /127\.0\.1\.1/ }
    hosts << "127.0.1.1   #{node['pi_bootstrap']['hostname_prefix']}-#{node['ipaddress'].split('.').last}\n"
    ::File.write('/etc/hosts', hosts.join)
  end
  only_if { ::File.exist?('/etc/hosts') }
end

# 3) Install required packages
package node['pi_bootstrap']['packages'] do
  action :install
end

# 4) Enable and start Docker
service 'docker' do
  action [:enable, :start]
  only_if { node['init_package'] == 'systemd' }
end

# 5) Enable and start WireGuard tools (wg-quick@<iface> can be managed later)
#service 'chrony' do
#  action [:enable, :start]
#end
