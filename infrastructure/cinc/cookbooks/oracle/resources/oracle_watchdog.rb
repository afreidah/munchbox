# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Resource:: oracle_watchdog
#
# Installs the oracle-watchdog .deb, lays down the (empty) config.yaml,
# wires the systemd Environment overrides with CONSUL_HTTP_ADDR + a
# Vault-fetched ACL token, and registers the daemon as a consul service
# for prometheus scrape.
#
# Vault token is fetched via `lazy { vault_fetch(...) }` so the read
# happens at converge time (after vault_agent::configure has gated on
# the token sink at /run/vault-agent/token).
# -------------------------------------------------------------------------------

unified_mode true

provides :oracle_watchdog

property :package_name,         String,        default: 'oracle-watchdog'
property :config_dir,           String,        default: '/etc/oracle-watchdog'
property :consul_addr,          String,        default: '127.0.0.1:8500'
property :metrics_port,         Integer,       default: 9104
property :vault_path,           String,        default: 'secret/data/consul/oracle-watchdog-token'
property :vault_field,          String,        default: 'token'
property :consul_service_file,  String,        default: '/etc/consul.d/oracle-watchdog.json'
property :service_name,         String,        default: 'oracle-watchdog'
property :consul_user,          String,        default: 'consul'
property :consul_group,         String,        default: 'consul'

default_action :configure

action :configure do
  pkg = new_resource.package_name
  svc = new_resource.service_name

  munchbox_base_apt_lock_wait "oracle_watchdog_install_#{new_resource.name}"

  apt_package pkg do
    action :upgrade
    notifies :restart, "service[#{svc}]", :delayed
  end

  directory new_resource.config_dir do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  template "#{new_resource.config_dir}/config.yaml" do
    source 'watchdog-config.yaml.erb'
    cookbook 'oracle'
    owner  'root'
    group  'root'
    mode   '0644'
    notifies :restart, "service[#{svc}]", :delayed
  end

  directory "/etc/systemd/system/#{svc}.service.d" do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  override = new_resource

  template "/etc/systemd/system/#{svc}.service.d/override.conf" do
    source 'watchdog-systemd-override.conf.erb'
    cookbook 'oracle'
    owner  'root'
    group  'root'
    mode   '0600'
    sensitive true
    variables(
      consul_addr: override.consul_addr,
      # --- vault_fetch deferred to converge time (see feedback_vault_fetch_lazy). ---
      consul_token: lazy { vault_fetch(override.vault_path, override.vault_field) }
    )
    notifies :run, 'execute[oracle_watchdog daemon-reload]', :immediately
    notifies :restart, "service[#{svc}]", :delayed
  end

  execute 'oracle_watchdog daemon-reload' do
    command 'systemctl daemon-reload'
    action  :nothing
  end

  template new_resource.consul_service_file do
    source 'watchdog-consul-service.json.erb'
    cookbook 'oracle'
    owner  new_resource.consul_user
    group  new_resource.consul_group
    mode   '0640'
    variables(
      metrics_port: new_resource.metrics_port
    )
    notifies :reload, 'service[consul]', :delayed
  end

  service svc do
    action %i(enable start)
  end

  # --- Stub so consul reload notify resolves; consul itself is owned by the consul cookbook. ---
  service 'consul' do
    action :nothing
  end
end
