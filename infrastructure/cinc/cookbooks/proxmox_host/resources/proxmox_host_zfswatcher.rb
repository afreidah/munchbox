# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_zfswatcher
#
# Manages the zfswatcher daemon (rouben/zfswatcher) -- conf at
# /etc/zfswatcher/zfswatcher.conf + systemd unit. Binary is assumed
# present at bin_path (built once on rubirosa from source; rebuild is
# operator-gated, not a converge concern).
#
# enabled=false stops + disables the service and deletes the conf;
# binary + log dir are left alone.
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_zfswatcher

property :enabled,             [true, false], default: false
property :bin_path,            String, default: '/opt/zfswatcher/zfswatcher'
property :config_path,         String, default: '/etc/zfswatcher/zfswatcher.conf'
property :log_dir,             String, default: '/var/log/zfswatcher'
property :bind,                String, default: '0.0.0.0:8800'
property :http_port,           Integer, default: 8800
property :template_dir,        String, default: '/opt/zfswatcher/src/www/templates'
property :resource_dir,        String, default: '/opt/zfswatcher/src/www/resources'
property :proxy_user,          String, default: 'proxy'
property :proxy_password_hash, String, sensitive: true
property :service_name,        String, default: 'zfswatcher'
property :advertise_ip,        String, default: '0.0.0.0'
property :consul_service_path, String, default: '/etc/consul.d/zfswatcher.json'

default_action :configure

action :configure do
  unless new_resource.enabled
    service new_resource.service_name do
      action [:stop, :disable]
      only_if "systemctl list-unit-files | grep -q '^#{new_resource.service_name}.service'"
    end
    file new_resource.config_path do
      action :delete
    end
    return
  end

  cookbook_name_str = cookbook_name.to_s

  directory ::File.dirname(new_resource.config_path) do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  directory new_resource.log_dir do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  template new_resource.config_path do
    cookbook cookbook_name_str
    source   'zfswatcher.conf.erb'
    owner    'root'
    group    'root'
    mode     '0640'
    sensitive true
    variables(
      bind:                new_resource.bind,
      template_dir:        new_resource.template_dir,
      resource_dir:        new_resource.resource_dir,
      log_dir:             new_resource.log_dir,
      proxy_user:          new_resource.proxy_user,
      proxy_password_hash: new_resource.proxy_password_hash
    )
    notifies :restart, "service[#{new_resource.service_name}]", :delayed
  end

  systemd_unit "#{new_resource.service_name}.service" do
    content <<~UNIT
      [Unit]
      Description=ZFS Watcher - Pool Monitoring Daemon
      Documentation=https://github.com/rouben/zfswatcher
      After=network.target zfs.target

      [Service]
      Type=simple
      User=root
      ExecStart=#{new_resource.bin_path} -c #{new_resource.config_path}
      ExecReload=/bin/kill -HUP $MAINPID
      Restart=on-failure
      RestartSec=5

      StandardOutput=journal
      StandardError=journal
      SyslogIdentifier=zfswatcher

      ExecStartPre=/bin/mkdir -p #{new_resource.log_dir}

      [Install]
      WantedBy=multi-user.target
    UNIT
    action [:create, :enable, :start]
    notifies :restart, "service[#{new_resource.service_name}]", :delayed
  end

  service new_resource.service_name do
    action :nothing
  end

  # --- Consul service registration with a real http health check (ansible-era external-service registration on phantom 'rubirosa-external' node had no checks). Gated on consul user existence so first converge on a greenfield node (where consul hasn't installed yet) doesn't blow up; written on subsequent converge. notifies :reload so consul picks it up without a restart. ---
  template new_resource.consul_service_path do
    cookbook cookbook_name_str
    source   'zfswatcher-consul-service.json.erb'
    owner    'consul'
    group    'consul'
    mode     '0640'
    variables(
      port:       new_resource.http_port,
      address:    new_resource.advertise_ip,
      check_host: '127.0.0.1'
    )
    notifies :reload, 'service[consul]', :delayed
    only_if { ::Etc.getpwnam('consul') rescue false }
  end

  service 'consul' do
    action :nothing
  end

  log "zfswatcher binary missing at #{new_resource.bin_path} -- daemon will fail to start until built (see rouben/zfswatcher README)" do
    level :warn
    not_if { ::File.exist?(new_resource.bin_path) }
  end
end
