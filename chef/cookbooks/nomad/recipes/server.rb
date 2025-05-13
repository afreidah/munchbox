include_recipe 'nomad::install'

template '/etc/nomad.d/server.hcl' do
  source 'config.hcl.erb'
  variables(
    server: true,
    bootstrap_expect: node['nomad']['servers'].size,
    retry_join: node['nomad']['servers'].map { |h| "#{h}:4647" }
  )
  notifies :restart, 'service[nomad]', :delayed
end

service 'nomad' do
  action [:enable, :start]
  only_if { node['init_package'] == 'systemd' }
end

