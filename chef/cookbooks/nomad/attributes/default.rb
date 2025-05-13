default['nomad']['version']        = '1.5.3'
default['nomad']['install_method']  = 'binary'
default['nomad']['servers']         = %w[pi-01 pi-02 pi-03]
default['nomad']['bind_addr']       = node['ipaddress']
default['nomad']['datacenter']      = 'pi-dc'
default['nomad']['data_dir']        = '/opt/nomad'

