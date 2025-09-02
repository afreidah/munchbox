# --------------------------------------------------------------------
# Cookbook:: consul
# Recipe:: snapshot
#
# Sets up a daily cron job to run `consul snapshot save`.
# The snapshot is saved to /var/backups/consul/consul.snap.
# --------------------------------------------------------------------

# Ensure backup directory exists
directory '/mnt/gdrive/nomad-snapshots' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
end

# Load and decrypt the management token from the data bag
management = data_bag_item('consul', 'management')
token = management['token']

cron 'consul_snapshot_save' do
  minute '15'
  hour '2'
  command [
    "CONSUL_HTTP_TOKEN=#{token}",
    "consul snapshot save",
    "/mnt/gdrive/consul-snapshots/consul-$(date +\\%Y\\%m\\%d\\%H\\%M\\%S).snap",
    ">> /var/log/consul_snapshot.log 2>&1"
  ].join(' ')
  user 'root'
end
