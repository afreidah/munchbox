# -------------------------------------------------------------------------------
# Nomad Cookbook - TLS Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures TLS certificates for secure Nomad cluster communication.
# -------------------------------------------------------------------------------

dc        = node['nomad']['dc']      || 'dc1'
is_server = node['nomad']['server']  || false
tls_dir  = '/opt/nomad/tls'
hostname = node['hostname']
ip       = node['ipaddress']
region   = (node.dig('nomad','region') || 'global')
domain   = 'nomad'

directory tls_dir do
  owner 'root'
  group 'root'
  mode  '0755'
  recursive true
end

# ----- CA: EITHER pull from data bag OR generate once on a bootstrap node -----

# pull CA from encrypted data bag (we are reusing the consul CA here)
ca_item = data_bag_item('consul', 'agent_ca')  # fields: cert, key
file "#{tls_dir}/nomad-agent-ca.pem" do
  content ca_item['cert']
  owner 'root'
  group 'root'
  mode  '0644'
end
file "#{tls_dir}/nomad-agent-ca-key.pem" do
  content ca_item['key']
  owner 'root'
  group 'root'
  mode  '0600'
  sensitive true
end

# ----- Issue node certs (server vs client) -----
if is_server
  # Server cert; include DC, domain, node name, and IP SAN
  execute 'nomad_tls_cert_create_server' do
    cwd tls_dir
    command [
      'nomad tls cert create -server',
      "-region #{region}",
      "-domain #{domain}",
      "-additional-dnsname #{hostname}",
      "-additional-ipaddress #{ip}",
      "-ca #{tls_dir}/nomad-agent-ca.pem",
      "-key #{tls_dir}/nomad-agent-ca-key.pem"
    ].join(' ')
    creates "#{tls_dir}/#{region}-server-#{domain}.pem"
    only_if { ::File.size?("#{tls_dir}/nomad-agent-ca.pem") && ::File.size?("#{tls_dir}/nomad-agent-ca-key.pem") }
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
  execute 'nomad_tls_cert_create_client' do
    cwd tls_dir
    command [
      'nomad tls cert create -client',
      "-additional-dnsname #{hostname}",
      "-additional-ipaddress #{ip}",
      "-ca #{tls_dir}/nomad-agent-ca.pem",
      "-key #{tls_dir}/nomad-agent-ca-key.pem"
    ].join(' ')
    creates "#{tls_dir}/#{region}-client-#{domain}.pem"
    only_if { ::File.size?("#{tls_dir}/nomad-agent-ca.pem") && ::File.size?("#{tls_dir}/nomad-agent-ca-key.pem") }
  end

  file "#{tls_dir}/nomad-client-0.pem" do
    mode '0644'
  end
  file "#{tls_dir}/nomad-client-0-key.pem" do
    mode '0600'
    sensitive true
  end
end

service 'nomad' do
  action [:enable, :start]
end
