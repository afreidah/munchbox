# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_auto_restart_webhook
#
# AlertManager webhook receiver that restarts Nomad jobs whose firing
# alerts carry labels `auto_restart=true` + `nomad_job=<name>`. Per-job
# cooldown absorbs flapping. Single port attribute drives both the
# listening script and the consul service check, so they can't drift
# (the pre-takeover python deploy silently moved to 9099 while
# AlertManager kept POSTing to 9095 and the consul check stayed red).
#
# Every visible knob is a property so other cookbooks / nodes can swap
# in custom paths, ports, ACL tokens, service names, dependencies, etc.
# Defaults reproduce the live stabler deployment.
#
# Actions:
#   :configure - render the script, install + start the unit, register with consul
#   :remove    - stop the unit, delete the script, unit, consul registration,
#                cooldown dir and log. No-op on a node that never had it, and
#                needs no nomad_token.
# -------------------------------------------------------------------------------

unified_mode true

provides :nomad_auto_restart_webhook

# --- Identity / service ---
property :service_name,         String,  default: 'nomad-auto-restart-webhook'
property :service_description,  String,  default: 'AlertManager Webhook for Nomad Job Auto-Restart'
property :user,                 String,  default: 'root'
property :group,                String,  default: 'root'

# --- Network / receiver behavior ---
property :port,                 Integer, default: 9095
property :bind_address,         String,  default: '0.0.0.0'
property :cooldown_seconds,     Integer, default: 300
property :cooldown_dir,         String,  default: '/tmp/nomad-restart-cooldown'
property :log_file,             String,  default: '/var/log/nomad-auto-restart.log'

# --- On-disk paths ---
property :python_bin,           String,  default: '/usr/bin/python3'
property :script_path,          String,  default: '/usr/local/bin/nomad-auto-restart-webhook.py'

# --- Systemd dependencies ---
property :after_units,          Array,   default: %w(network.target nomad.service)
property :wants_units,          Array,   default: %w(nomad.service)
property :restart_policy,       String,  default: 'always'
property :restart_sec,          Integer, default: 5

# --- Nomad client env (mTLS to the local agent) ---
property :nomad_addr,           String,  default: 'https://127.0.0.1:4646'
property :nomad_cacert,         String,  default: '/etc/nomad.d/tls/ca.crt'
property :nomad_client_cert,    String,  default: '/etc/nomad.d/tls/nomad.crt'
property :nomad_client_key,     String,  default: '/etc/nomad.d/tls/nomad.key'
property :nomad_token,          [String, nil], required: [:configure], sensitive: true

# --- Consul service registration ---
property :consul_service_file,  String,  default: '/etc/consul.d/nomad-auto-restart-webhook.json'
property :consul_service_name,  String,  default: 'nomad-auto-restart-webhook'
property :consul_service_tags,  Array,   default: %w(alertmanager webhook infrastructure)
property :consul_check_interval, String, default: '30s'
property :consul_check_timeout,  String, default: '5s'
property :consul_check_path,    String,  default: '/'
property :consul_user,          String,  default: 'consul'
property :consul_group,         String,  default: 'consul'

# --- Predecessor files swept on every converge ---
property :stale_paths,          Array,   default: []

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  raise "nomad_auto_restart_webhook[#{new_resource.name}]: nomad_token cannot be empty" if new_resource.nomad_token.to_s.empty?

  # --- Sweep predecessor scripts (ansible-era bash version, etc.) ---
  new_resource.stale_paths.each do |path|
    file path do
      action :delete
    end
  end

  template new_resource.script_path do
    source 'auto-restart-webhook.py.erb'
    cookbook 'nomad'
    owner  new_resource.user
    group  new_resource.group
    mode   '0755'
    variables(
      port: new_resource.port,
      bind_address: new_resource.bind_address,
      cooldown_seconds: new_resource.cooldown_seconds,
      cooldown_dir: new_resource.cooldown_dir,
      log_file: new_resource.log_file
    )
    notifies :restart, "service[#{new_resource.service_name}]", :delayed
  end

  unit = new_resource

  systemd_unit "#{unit.service_name}.service" do
    content <<~UNIT
      [Unit]
      Description=#{unit.service_description}
      After=#{unit.after_units.join(' ')}
      Wants=#{unit.wants_units.join(' ')}

      [Service]
      Type=simple
      User=#{unit.user}
      Group=#{unit.group}
      Environment=NOMAD_ADDR=#{unit.nomad_addr}
      Environment=NOMAD_CACERT=#{unit.nomad_cacert}
      Environment=NOMAD_CLIENT_CERT=#{unit.nomad_client_cert}
      Environment=NOMAD_CLIENT_KEY=#{unit.nomad_client_key}
      Environment=NOMAD_TOKEN=#{unit.nomad_token}
      ExecStart=#{unit.python_bin} #{unit.script_path}
      Restart=#{unit.restart_policy}
      RestartSec=#{unit.restart_sec}

      [Install]
      WantedBy=multi-user.target
    UNIT
    action %i(create enable start)
    notifies :restart, "service[#{unit.service_name}]", :delayed
  end

  template new_resource.consul_service_file do
    source 'auto-restart-webhook-consul-service.json.erb'
    cookbook 'nomad'
    owner  new_resource.consul_user
    group  new_resource.consul_group
    mode   '0640'
    variables(
      service_name: new_resource.consul_service_name,
      tags: new_resource.consul_service_tags,
      port: new_resource.port,
      check_path: new_resource.consul_check_path,
      interval: new_resource.consul_check_interval,
      timeout: new_resource.consul_check_timeout
    )
    notifies :reload, 'service[consul]', :delayed
  end

  service new_resource.service_name do
    action %i(enable start)
  end

  # --- Declared so the consul-service template can notify a reload; consul itself is owned by the consul cookbook. ---
  service 'consul' do
    action :nothing
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Stop the unit, then delete everything :configure creates
# -------------------------------------------------------------------------------

action :remove do
  # --- Stop before the unit file goes; systemctl can't stop what it can't see ---
  service new_resource.service_name do
    action %i(stop disable)
    only_if "systemctl list-unit-files | grep -q '^#{new_resource.service_name}.service'"
  end

  systemd_unit "#{new_resource.service_name}.service" do
    action :delete
  end

  file new_resource.consul_service_file do
    action :delete
    notifies :reload, 'service[consul]', :delayed
  end

  paths = [new_resource.script_path, new_resource.log_file] + new_resource.stale_paths.to_a

  paths.each do |path|
    file path do
      action :delete
    end
  end

  directory new_resource.cooldown_dir do
    recursive true
    action :delete
  end

  # --- Declared so the consul-service delete can notify a reload; consul itself is owned by the consul cookbook. ---
  service 'consul' do
    action :nothing
  end
end
