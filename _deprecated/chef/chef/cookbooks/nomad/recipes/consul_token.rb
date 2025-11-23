# ------------------------------------------------------------
# Consul token → Nomad agent (env file + systemd drop-in)
# - Loads role-appropriate token from encrypted data bag
# - Keeps token out of HCL; stores with 0600 perms
# ------------------------------------------------------------

# Decide which Consul token item to use based on node role
bag_item = node.dig('nomad', 'server', 'enabled') ? 'nomad_server' : 'nomad_client'

ruby_block 'load_consul_token' do
  block do
    item = Chef::EncryptedDataBagItem.load('consul', bag_item)
    node.run_state['consul_http_token'] = item['token']
  end
end

directory '/etc/nomad.d' do
  owner 'root'
  group 'root'
  mode '0755'
end

# Write token to env file with strict permissions
file '/etc/nomad.d/consul_token.env' do
  owner 'root'
  group 'root'
  mode '0600'
  sensitive true                     # do not print token in logs
  content lazy {
    tok = node.run_state['consul_http_token']
    raise 'Consul token not found in data bag' if tok.to_s.empty?
    "CONSUL_HTTP_TOKEN=#{tok}\n"
  }
end

# Systemd drop-in to load the env file for the Nomad service
directory '/etc/systemd/system/nomad.service.d' do
  owner 'root'
  group 'root'
  mode '0755'
end

file '/etc/systemd/system/nomad.service.d/10-consul-token.conf' do
  owner 'root'
  group 'root'
  mode '0644'
  content <<~UNIT
    [Service]
    EnvironmentFile=/etc/nomad.d/consul_token.env
  UNIT
  notifies :run, 'execute[systemd-daemon-reload]', :immediately
end

execute 'systemd-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'nomad' do
  action :nothing
  subscribes :restart, 'file[/etc/nomad.d/consul_token.env]', :immediately
  subscribes :restart, 'file[/etc/systemd/system/nomad.service.d/10-consul-token.conf]', :immediately
end
