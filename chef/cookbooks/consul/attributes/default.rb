# consul::default attributes
default['consul']['version']       = '1.14.4'
default['consul']['install_method'] = 'binary'
default['consul']['bind_addr']       = node['ipaddress']

# Raft quorum members
default['consul']['servers'] = %w[
  pi-225
  pi-98
]

default['consul']['config_dir'] = '/etc/consul.d'
default['consul']['user'] = 'root'
default['consul']['group'] = 'root'
default['consul']['bind_addr'] = node['ipaddress']
default['consul']['install_dir'] = '/usr/local/bin'
default['consul']['data_dir'] = '/opt/consul'
