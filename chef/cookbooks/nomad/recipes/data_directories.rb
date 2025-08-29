# ------------------------------------------------------------
# Sets up Nomad data directories with appropriate permissions
#  - Creates directories defined in node['nomad']['data_dirs']
# ------------------------------------------------------------

node['nomad']['client']['host_volumes'].each do |volume|
  directory volume['path'] do
    owner node['nomad']['user']
    group node['nomad']['group']
    mode '0755'
    recursive true
    action :create
  end
end
