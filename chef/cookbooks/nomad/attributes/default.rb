default['nomad']['version']        = '1.5.3'
default['nomad']['install_method']  = 'binary'
default['nomad']['bind_addr']       = node['ipaddress']
default['nomad']['datacenter']      = 'pi-dc'
default['nomad']['data_dir']        = '/opt/nomad'
default['nomad']['config_dir']      = '/etc/nomad.d'
default['nomad']['user']           = 'root'
default['nomad']['group']          = 'root'
default['nomad']['servers'] = %w[
  pi-225
  pi-98
]

