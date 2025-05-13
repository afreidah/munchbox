#
# Cookbook:: nomad
# Recipe:: install
#
# Download & install the Nomad binary (or use the official HashiCorp repo)

include_recipe 'consul::install' # if you reuse the same install helper

archive_file 'nomad' do
  path        '/tmp/nomad.zip'
  source      "https://releases.hashicorp.com/nomad/#{node['nomad']['version']}/nomad_#{node['nomad']['version']}_linux_arm64.zip"
  checksum    '<SHA256_SUM>'
  notifies    :run, 'execute[unzip-nomad]', :immediately
end

execute 'unzip-nomad' do
  command 'unzip -o /tmp/nomad.zip -d /usr/local/bin'
  action  :nothing
end

directory node['nomad']['data_dir'] do
  owner 'root'
  group 'root'
  mode  '0755'
  recursive true
end

