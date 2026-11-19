# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: firecracker
# Recipe:: host
#
# Readies the node for the vagabond agent's -firecracker: Firecracker's user,
# and containerd's devmapper snapshotter on a thin pool of its own.
# -------------------------------------------------------------------------------

host = node[cookbook]['host']

firecracker_host 'firecracker' do
  pool_dir        host['pool_dir']
  pool_name       host['pool_name']
  data_size       host['data_size']
  meta_size       host['meta_size']
  base_image_size host['base_image_size']
  fs_type         host['fs_type']
  uid             host['uid']
  gid             host['gid']
end
