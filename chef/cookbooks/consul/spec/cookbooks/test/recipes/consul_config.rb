consul_config 'default' do
  config_dir '/etc/consul.d'
  install_dir '/opt/consul'
  user 'consul'
  group 'consul'
  action :create
end
