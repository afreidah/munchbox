# recipes/tls.rb
tls_dir   = '/opt/consul/tls'
dc        = node['consul']['dc']      || 'dc1'
domain    = node['consul']['domain']  || 'consul'
is_server = node['consul']['server']  || false
hostname  = node['hostname']
ip        = node['ipaddress']

directory tls_dir do
  owner 'root'
  group 'root'
  mode  '0755'
  recursive true
end

# ----- CA: EITHER pull from data bag OR generate once on a bootstrap node -----

# pull CA from encrypted data bag (recommended once you’ve created it)
ca_item = data_bag_item('consul', 'agent_ca')  # fields: cert, key
file "#{tls_dir}/consul-agent-ca.pem" do
  content ca_item['cert']
  owner 'root'
  group 'root'
  mode  '0644'
end
file "#{tls_dir}/consul-agent-ca-key.pem" do
  content ca_item['key']
  owner 'root'
  group 'root'
  mode  '0600'
  sensitive true
end

# ----- Issue node certs (server vs client) -----
if is_server
  # Server cert; include DC, domain, node name, and IP SAN
  execute 'consul_tls_cert_create_server' do
    cwd     tls_dir
    command [
      'consul tls cert create -server',
      "-dc #{dc}",
      "-domain #{domain}",
      "-node #{hostname}",
      "-additional-ipaddress #{ip}",
      "-ca #{tls_dir}/consul-agent-ca.pem",
      "-key #{tls_dir}/consul-agent-ca-key.pem"
    ].join(' ')
    creates "#{tls_dir}/#{dc}-server-#{domain}-0.pem"  # sentinel
    environment({ 'CONSUL_CACERT' => "#{tls_dir}/consul-agent-ca.pem" })
  end

  # Tighten perms
  file "#{tls_dir}/#{dc}-server-#{domain}-0.pem" do
    mode '0644'
  end
  file "#{tls_dir}/#{dc}-server-#{domain}-0-key.pem" do
    mode '0600'
    sensitive true
  end
else
  # Client cert for agents/cli
  execute 'consul_tls_cert_create_client' do
    cwd     tls_dir
    command [
      'consul tls cert create -client',
      "-additional-ipaddress #{ip}",
      "-ca #{tls_dir}/consul-agent-ca.pem",
      "-key #{tls_dir}/consul-agent-ca-key.pem"
    ].join(' ')
    creates "#{tls_dir}/consul-client-0.pem"  # sentinel
    environment({ 'CONSUL_CACERT' => "#{tls_dir}/consul-agent-ca.pem" })
  end

  file "#{tls_dir}/consul-client-0.pem" do
    mode '0644'
  end
  file "#{tls_dir}/consul-client-0-key.pem" do
    mode '0600'
    sensitive true
  end
end

# ----- Drop TLS config fragment (you can merge this into your consul.hcl template) -----
template '/etc/consul.d/tls.hcl' do
  owner 'root'
  group 'root'
  mode  '0644'
  variables(
    tls_dir: tls_dir,
    dc: dc,
    domain: domain,
    is_server: is_server
  )
  notifies :restart, 'service[consul]', :delayed
end

service 'consul' do
  action [:enable, :start]
end
