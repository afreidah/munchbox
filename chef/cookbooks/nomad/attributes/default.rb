# nomad::default attributes
default['nomad']['datacenter']      = 'pi-dc'
default['nomad']['version']         = '1.5.3'
default['nomad']['install_method']  = 'binary'

# Raft quorum members
default['nomad']['servers'] = %w(
  192.168.1.225
  192.168.1.98
)
#  pi-98

default['nomad']['user']       = 'root'
default['nomad']['group']      = 'root'
default['nomad']['config_dir'] = '/etc/nomad.d/'
default['nomad']['data_dir']   = '/opt/nomad/'
default['nomad']['bind_addr']  = node['ipaddress']
