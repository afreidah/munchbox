#
# Cookbook:: pi_bootstrap
# Recipe:: default
#

# 1) Compute a unique hostname (e.g. pi-42 for IP x.x.x.42)
octet = node['ipaddress'].split('.').last
new_name = "#{node['pi_bootstrap']['hostname_prefix']}-#{octet}"

# 2) Set /etc/hostname & /etc/hosts
template '/etc/hostname' do
  source 'hostname.erb'
  variables(hostname: new_name)
  notifies :run, 'execute[hostnamectl-set]', :immediately
end

execute 'hostnamectl-set' do
  command "hostnamectl set-hostname #{new_name}"
  action :nothing
end

ruby_block 'update_etc_hosts' do
  block do
    hosts = ::File.read('/etc/hosts').lines.reject { |l| l =~ /127\.0\.1\.1/ }
    hosts << "127.0.1.1   #{new_name}\n"
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
