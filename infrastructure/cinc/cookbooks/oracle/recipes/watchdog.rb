# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Recipe:: watchdog
#
# Installs the oracle-watchdog package from the munchbox aptly repo,
# drops the (currently empty) /etc/oracle-watchdog/config.yaml, wires
# the systemd Environment= overrides with CONSUL_HTTP_ADDR + ACL token
# (fetched from Vault), and registers the watchdog as a consul service
# for prometheus scrape.
#
# Per `feedback_vault_fetch_lazy` -- vault_fetch is wrapped in lazy {}
# so it runs at converge time, after vault_agent::configure has gated
# on /run/vault-agent/token.
# -------------------------------------------------------------------------------

# --- Pre-resolve here; `cookbook` is shadowed inside template/file blocks. ---
watchdog = node[cookbook]['watchdog']

# --- Wait for apt lock; earlier recipes may still be holding it. ---
munchbox_base_apt_lock_wait 'oracle_watchdog_install'

apt_package watchdog['package_name'] do
  action :upgrade
  notifies :restart, 'service[oracle-watchdog]', :delayed
end

# --- Config dir + empty config.yaml so the daemon finds it (uses built-in defaults). ---
directory watchdog['config_dir'] do
  owner 'root'
  group 'root'
  mode  '0755'
end

template "#{watchdog['config_dir']}/config.yaml" do
  source 'watchdog-config.yaml.erb'
  owner  'root'
  group  'root'
  mode   '0644'
  notifies :restart, 'service[oracle-watchdog]', :delayed
end

# --- Systemd drop-in: CONSUL_HTTP_ADDR + lazy-fetched ACL token. ---
directory '/etc/systemd/system/oracle-watchdog.service.d' do
  owner 'root'
  group 'root'
  mode  '0755'
end

template '/etc/systemd/system/oracle-watchdog.service.d/override.conf' do
  source 'watchdog-systemd-override.conf.erb'
  owner  'root'
  group  'root'
  mode   '0600'
  sensitive true
  variables(
    consul_addr: watchdog['consul_addr'],
    # --- vault_fetch deferred to converge time (see feedback_vault_fetch_lazy). ---
    consul_token: lazy { vault_fetch(watchdog['vault_path'], watchdog['vault_field']) }
  )
  notifies :run, 'execute[systemctl daemon-reload]', :immediately
  notifies :restart, 'service[oracle-watchdog]', :delayed
end

execute 'systemctl daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# --- Consul service registration. Consul scans /etc/consul.d/ on SIGHUP; we notify for immediacy. ---
template watchdog['consul_service_file'] do
  source 'watchdog-consul-service.json.erb'
  owner  'consul'
  group  'consul'
  mode   '0640'
  variables(
    metrics_port: watchdog['metrics_port']
  )
  notifies :reload, 'service[consul]', :delayed
end

service 'oracle-watchdog' do
  action %i(enable start)
end

# --- Stub for the reload notify; consul itself is owned by the consul cookbook. ---
service 'consul' do
  action :nothing
end
