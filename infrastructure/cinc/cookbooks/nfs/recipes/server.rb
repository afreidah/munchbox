# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nfs
# Recipe:: server
#
# Installs nfs-kernel-server and renders /etc/exports from
# node[cookbook][:server][:exports]. Empty list = recipe no-op.
# -------------------------------------------------------------------------------

server = node[cookbook]['server']

nfs_server 'nfs-server' do
  package        server['package']
  exports        server['exports']
  exports_path   server['exports_path']
  service_name   server['service_name']
end
