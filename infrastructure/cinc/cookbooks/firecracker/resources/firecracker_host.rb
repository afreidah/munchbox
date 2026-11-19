# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: firecracker
# Resource:: firecracker_host
#
# Readies a node for the vagabond agent's -firecracker: containerd's devmapper
# snapshotter, which turns each image into the block device a microVM boots
# from, on a thin pool over two sparse files brought up at boot ahead of
# containerd; and the user Firecracker runs as, made so nothing else takes its
# UID.
#
# Properties:
#   pool_dir        - Where the pool's sparse data and metadata files live.
#   pool_name       - The thin pool's device-mapper name.
#   data_size       - The data file's size, as truncate takes it. Sparse, so
#                     disk is used only as microVMs write.
#   meta_size       - The metadata file's size.
#   base_image_size - Each image's snapshot size: the microVM's disk.
#   fs_type         - The filesystem made on each snapshot.
#   uid, gid        - Firecracker's user and group, the agent's
#                     -firecracker-uid and -firecracker-gid.
# -------------------------------------------------------------------------------

unified_mode true

provides :firecracker_host

property :pool_dir,        String,  default: '/var/lib/containerd-thinpool'
property :pool_name,       String,  default: 'containerd-thinpool'
property :data_size,       String,  default: '50G'
property :meta_size,       String,  default: '1G'
property :base_image_size, String,  default: '10GB'
property :fs_type,         String,  default: 'ext4'
property :uid,             Integer, default: 990
property :gid,             Integer, default: 990

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Firecracker's user, the thin pool, containerd's config
# -------------------------------------------------------------------------------

action :configure do
  # --- Made rather than assumed free, so a UID or GID already taken fails the converge. ---
  group 'firecracker' do
    gid    new_resource.gid
    system true
  end

  user 'firecracker' do
    uid    new_resource.uid
    gid    new_resource.gid
    system true
    shell  '/usr/sbin/nologin'
    home   '/nonexistent'
  end

  munchbox_base_apt_lock_wait 'firecracker_host_install'

  apt_package 'dmsetup'

  directory new_resource.pool_dir do
    owner 'root'
    group 'root'
    mode  '0700'
  end

  # --- Makes the files the first time, reattaches them after a boot, and leaves a live pool be. ---
  file '/usr/local/sbin/containerd-thinpool' do
    content <<~SCRIPT
      #!/bin/bash
      # Managed by chef (firecracker::host) -- do not edit by hand.
      set -euo pipefail

      dir=#{new_resource.pool_dir}
      pool=#{new_resource.pool_name}

      dmsetup status "${pool}" > /dev/null 2>&1 && exit 0

      [[ -e "${dir}/data" ]] || truncate -s #{new_resource.data_size} "${dir}/data"
      [[ -e "${dir}/meta" ]] || truncate -s #{new_resource.meta_size} "${dir}/meta"

      # The loop device a file is already on, or a new one
      attach() {
        local loop
        loop=$(losetup --associated "$1" --noheadings --output NAME | head -n 1)
        echo "${loop:-$(losetup --find --show "$1")}"
      }

      data=$(attach "${dir}/data")
      meta=$(attach "${dir}/meta")
      dmsetup create "${pool}" --table "0 $(blockdev --getsz "${data}") thin-pool ${meta} ${data} 128 32768"
    SCRIPT
    owner 'root'
    group 'root'
    mode  '0755'
  end

  # --- Before containerd, whose snapshotter needs the pool as it starts. Wanted, not required: a failed pool leaves containerd, and Docker, running without it. ---
  systemd_unit 'containerd-thinpool.service' do
    content <<~UNIT
      # Managed by chef (firecracker::host) -- do not edit by hand.
      [Unit]
      Description=containerd's devmapper thin pool
      After=local-fs.target
      Before=containerd.service

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStartPre=/sbin/modprobe dm_thin_pool
      ExecStart=/usr/local/sbin/containerd-thinpool

      [Install]
      WantedBy=containerd.service
    UNIT
    action %i(create enable start)
  end

  # --- The whole file: Docker's stock one only disables CRI's server, which version 3 names in full. Discards punch the freed blocks back out of the sparse file. ---
  file '/etc/containerd/config.toml' do
    content <<~TOML
      # Managed by chef (firecracker::host) -- do not edit by hand.
      version = 3

      disabled_plugins = ["io.containerd.grpc.v1.cri"]

      [plugins."io.containerd.snapshotter.v1.devmapper"]
        pool_name = "#{new_resource.pool_name}"
        base_image_size = "#{new_resource.base_image_size}"
        fs_type = "#{new_resource.fs_type}"
        discard_blocks = true
    TOML
    owner 'root'
    group 'root'
    mode  '0644'
    notifies :restart, 'service[containerd]', :delayed
  end

  service 'containerd' do
    action :nothing
  end
end
