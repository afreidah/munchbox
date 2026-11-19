# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: firecracker
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Host
#
# - pool_dir, pool_name: the thin pool's sparse files and device-mapper name.
# - data_size, meta_size: the files' sizes, fixed when first made. Sparse, but
#     the data file must fit the disk once microVMs fill it.
# - base_image_size, fs_type: each image's snapshot, the microVM's disk.
# - uid, gid: the user and group Firecracker runs as, matching the agent's
#     -firecracker-uid and -firecracker-gid.
# -------------------------------------------------------------------------------

default[cookbook]['host'] = {
  pool_dir: '/var/lib/containerd-thinpool',
  pool_name: 'containerd-thinpool',
  data_size: '50G',
  meta_size: '1G',
  base_image_size: '10GB',
  fs_type: 'ext4',
  uid: 990,
  gid: 990,
}
