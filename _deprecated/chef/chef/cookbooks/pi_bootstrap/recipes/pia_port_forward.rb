# -------------------------------------------------------------------------------
# Pi Bootstrap Cookbook - PIA Port Forward Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Sets up PIA port forwarding service via systemd.
# -------------------------------------------------------------------------------

pia_item = data_bag_item('pia_vpn', 'wg')

template '/etc/systemd/system/pia-portforward.service' do
  source 'port-forward.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    pia_token: pia_item['pia_token'],
    pf_gateway: pia_item['pf_gateway'],
    pf_hostname: pia_item['pf_hostname']
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'pia-portforward' do
  action [:enable, :start]
end
