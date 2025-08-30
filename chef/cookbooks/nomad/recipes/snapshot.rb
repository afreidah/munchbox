# --------------------------------------------------------------------
# Cookbook:: nomad
# Recipe:: nomad
#
# Sets up a daily cron job to run `nomad snapshot save` using the
# management token from the encrypted data bag `nomad/management`.
# The snapshot is saved to /var/backups/nomad/nomad.snap.
# --------------------------------------------------------------------

# Ensure backup directory exists
directory '/mnt/gdrive/nomad-snapshots' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
end

# Load and decrypt the management token from the data bag
management = data_bag_item('nomad', 'management')
management_token = management['secret_id']

# Set up the cron job to run the snapshot daily at 2:00 AM
cron 'nomad_snapshot_save' do
  minute '0'
  hour '2'
  command 'nomad operator snapshot save /mnt/gdrive/nomad-snapshots/nomad-$(date +\\%Y\\%m\\%d\\%H\\%M\\%S).snap'
  user 'root'
  environment({ 'NOMAD_TOKEN' => management_token })
end
