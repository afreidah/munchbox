# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_configure
# Purpose:: Render config, dirs, sysctls, unit; optional CNI install.
# --------------------------------------------------------------------
property :config_dir,     String, default: '/etc/nomad.d'
property :data_dir,       String, default: '/opt/nomad'
property :bind_addr,      String, default: lazy { node['ipaddress'] }
property :datacenter,     String, default: 'dc1'
property :server_enabled, [true, false], default: true
property :client_enabled, [true, false], default: true
property :retry_join,     Array, default: []
property :consul_auto,    [true, false], default: true
property :telemetry,      Hash,   default: {}
property :docker,         Hash,   default: {}
property :vault,          Hash,   default: {} # { 'enabled'=>true, 'address'=>'...', 'token'=> '...' }
property :user,           String, default: 'root'
property :group,          String, default: 'root'
property :enable_cni,     [true, false], default: true
property :cni_version,    String, default: 'v1.6.2'
property :cni_path,       String, default: '/opt/cni/bin'
property :cni_url_base,   String, default: 'https://github.com/containernetworking/plugins/releases/download'
property :consul_enabled,   [true, false], default: true
property :consul_address,   String,         default: lazy { "#{node['ipaddress']}:8500" }
property :consul_auto_adv,  [true, false],  default: true
property :consul_auto_join, [true, false],  default: true

default_action :apply

# --- Name of resource for Nomad cluster configuration ---
provides :nomad_configure
unified_mode true

action :apply do
  # Dirs with appropriate perms
  [new_resource.config_dir, new_resource.data_dir].each do |d|
    directory d do
      owner new_resource.user
      group new_resource.group
      mode(d == new_resource.config_dir ? '0750' : '0755')
      recursive true
    end
  end

  # Optional CNI install
  if new_resource.enable_cni
    arch = NomadCookbook::Helper.arch_for(node)
    base = "#{new_resource.cni_url_base}/cni-plugin-linux-#{arch}-#{new_resource.cni_version}.tgz"
    cni_tgz = ::File.join(Chef::Config[:file_cache_path], 'cni-plugins.tgz')
    remote_file cni_tgz do
      source base
      mode '0644'
      not_if { ::File.exist?(::File.join(new_resource.cni_path, 'bridge')) }
      notifies :extract, "archive_file[#{cni_tgz}]", :immediately
    end

    directory new_resource.cni_path do
      owner 'root'
      group 'root'
      mode '0755'
      recursive true
    end

    archive_file cni_tgz do
      destination new_resource.cni_path
      overwrite false
      action :nothing
    end

    # sysctl bridge settings for CNI
    template '/etc/sysctl.d/bridge.conf' do
      source 'bridge.conf.erb'
      mode   '0644'
      notifies :run, 'execute[apply-sysctl]', :immediately
    end

    execute 'apply-sysctl' do
      command 'sysctl --system'
      action :nothing
    end
  end

  # Render Nomad HCL
  template ::File.join(new_resource.config_dir, 'server.hcl') do
    source 'config.hcl.erb'
    owner  new_resource.user
    group  new_resource.group
    mode   '0640'
    sensitive true
    variables(
      retry_join: new_resource.retry_join,
      token: new_resource.vault['token'] || ''
      # consul variables consumed by the ERB via node attrs OR pass them as locals if you prefer
    )
  end

  # Systemd unit (hardened)
  systemd_unit 'nomad.service' do
    content <<~UNIT
      [Unit]
      Description=nomad Agent
      Documentation=https://www.nomad.io/
      Requires=network-online.target
      After=network-online.target

      [Service]
      User=#{node['nomad']['service_user']}
      Group=#{node['nomad']['service_group']}
      ExecStartPre=/bin/chown -R #{node['nomad']['service_user']}:#{node['nomad']['service_group']} #{node['nomad']['data_dir']}
      Restart=on-failure
      ExecStart=/usr/local/bin/nomad agent -config=#{node['nomad']['config_dir']}

      [Install]
      WantedBy=multi-user.target
    UNIT
    action [:create, :enable, :start]
  end
end
