# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# oracle::watchdog
#
# Monitor that maintains a Consul session heartbeat as the oracle node's
# health signal. Ships as a .deb in the munchbox aptly repo; the recipe
# wires up the systemd override env vars (CONSUL_HTTP_ADDR + ACL token)
# and registers a consul service for prometheus scrape.
#
# vault_path holds the dedicated `consul/oracle-watchdog-token` (NOT the
# shared agent-token); needs to be added to the chef-managed-node policy.
# -------------------------------------------------------------------------------

default[cookbook]['watchdog'] = {
  package_name: 'oracle-watchdog',
  config_dir: '/etc/oracle-watchdog',
  consul_addr: '127.0.0.1:8500',
  metrics_port: 9104,
  vault_path: 'secret/data/consul/oracle-watchdog-token',
  vault_field: 'token',
  consul_service_file: '/etc/consul.d/oracle-watchdog.json',
}

# -------------------------------------------------------------------------------
# oracle::minio_mount
#
# Persists the OCI block volume (label: minio-data) at /mnt/minio-data.
# Without this, a kernel-upgrade reboot leaves the volume detached and
# MinIO comes up against an empty root-fs stub -- which is exactly how
# the bucket on oracle-arm-2 went missing in May 2026.
#
# UUID is looked up at converge time via `blkid -t LABEL=<label>`. The
# legacy /dev/sdb fstab entry from the pre-UUID era is cleaned up if
# present.
# -------------------------------------------------------------------------------

default[cookbook]['minio_mount'] = {
  mount_point: '/mnt/minio-data',
  label: 'minio-data',
  fstype: 'ext4',
  options: 'defaults,nofail,_netdev',
  legacy_device: '/dev/sdb',
}
