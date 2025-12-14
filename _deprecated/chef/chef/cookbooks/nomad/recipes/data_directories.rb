# -------------------------------------------------------------------------------
# Nomad Cookbook - Data Directories Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Sets up Nomad data directories with appropriate permissions.
# -------------------------------------------------------------------------------

node['nomad']['client']['host_volumes'].each do |volume|
  directory volume['path'] do
    owner node['nomad']['user']
    group node['nomad']['group']
    mode '0755'
    recursive true
    action :create
  end
end
