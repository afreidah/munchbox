# recipes/jobs.rb

# nomad_job 'traefik' do
#   source     'jobs/traefik.nomad.hcl.erb'
#   variables(
#     datacenter:  node['nomad']['datacenter'],
#     consul_addr: "#{node['consul']['servers'].first}:8500",
#     data_dir:    node['nomad']['data_dir'],
#     cf_api_token: chef_vault_item('vault', 'traefik')['cf_api_token']
#   )
#   action :run
# end

