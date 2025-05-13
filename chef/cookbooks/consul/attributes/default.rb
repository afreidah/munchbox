# consul::default attributes
default['consul']['version']       = '1.14.4'
default['consul']['install_method'] = 'binary'

# Raft quorum members
default['consul']['servers'] = %w[pi-01 pi-02 pi-03]

