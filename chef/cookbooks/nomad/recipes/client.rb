include_recipe 'nomad::install'

template '/etc/nomad.d/client.hcl' do
  source 'config.hcl.erb'
  variables(
    server: false,
    retry_join: node['nomad']['servers'].map { |h| "#{h}:4647" }
  )
  notifies :restart, 'service[nomad]', :delayed
end

template '/etc/systemd/system/nomad.service' do
  source     'nomad.service.erb'
  variables(
    server: false
  )
  owner      node['nomad']['user']
  group      node['nomad']['group']
  mode       '0644'
  #notifies   :restart, 'service[nomad]', :delayed
end

# service 'nomad.service' do
#   action [:enable, :start, :restart]
#   only_if { node['init_package'] == 'systemd' }
# end

