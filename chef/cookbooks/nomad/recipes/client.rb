include_recipe 'nomad::install'

template '/etc/nomad.d/client.hcl' do
  source 'config.hcl.erb'
  variables(
    server: false,
    retry_join: node['nomad']['servers'].map { |h| "#{h}:4647" }
  )
  notifies :restart, 'service[nomad]', :delayed
end

service 'nomad' do
  action [:enable, :start]
  only_if { node['init_package'] == 'systemd' }
end

