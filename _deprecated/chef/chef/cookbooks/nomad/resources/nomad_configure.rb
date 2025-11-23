# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_configure
# Purpose:: Render config, dirs, sysctls, unit; optional CNI install.
#           Starts/enables service via notifications (single control point).
# --------------------------------------------------------------------

property :config_dir,       String, default: '/etc/nomad.d'
property :data_dir,         String, default: '/opt/nomad'
property :bind_addr,        String, default: lazy { node['ipaddress'] }
property :datacenter,       String, default: 'dc1'
property :server_enabled,   [true, false]
property :client_enabled,   [true, false], default: true
property :retry_join,       Array, default: []
property :consul_auto,      [true, false], default: true
property :telemetry,        Hash,   default: {}
property :docker,           Hash,   default: {}
property :vault_token,      String
property :user,             String, default: 'root'
property :group,            String, default: 'root'
property :enable_cni,       [true, false], default: true
property :cni_version,      String, default: 'v1.6.2'
property :cni_path,         String, default: '/opt/cni/bin'
property :cni_url_base,     String, default: 'https://github.com/containernetworking/plugins/releases/download'
property :consul_enabled,   [true, false], default: true
property :consul_address,   String,         default: lazy { "#{node['ipaddress']}:8500" }
property :consul_auto_adv,  [true, false],  default: true
property :consul_auto_join, [true, false],  default: true

default_action :apply

# --- Name of resource for Nomad cluster configuration ---
provides :nomad_configure
unified_mode true

action :apply do

  # Nomad gossip key from encrypted data bag
  begin
    item = Chef::EncryptedDataBagItem.load('nomad', 'gossip')
    node.default['nomad']['server']['gossip_encrypt'] = item['encrypt']
  rescue => e
    Chef::Log.warn("Nomad gossip key not loaded (proceeding without encryption): #{e}")
  end

  # ------------------------------------------------------------------
  # Directories (config/data) with appropriate ownership and perms
  # ------------------------------------------------------------------
  [new_resource.config_dir, new_resource.data_dir].each do |d|
    directory d do
      owner new_resource.user
      group new_resource.group
      mode(d == new_resource.config_dir ? '0750' : '0755')
      recursive true
    end
  end

  # ------------------------------------------------------------------
  # Optional CNI plugins install (corrected URL/filename)
  # ------------------------------------------------------------------
  if new_resource.enable_cni
    arch      = NomadCookbook::Helper.arch_for(node) # amd64/arm64
    tag       = new_resource.cni_version             # e.g., v1.6.2
    file_name = "cni-plugins-linux-#{arch}-#{tag}.tgz"
    source_url = "#{new_resource.cni_url_base}/#{tag}/#{file_name}"
    cni_tgz   = ::File.join(Chef::Config[:file_cache_path], file_name)

    directory new_resource.cni_path do
      owner 'root'
      group 'root'
      mode '0755'
      recursive true
    end

    remote_file cni_tgz do
      source source_url
      mode '0644'
      not_if { ::File.exist?(::File.join(new_resource.cni_path, 'bridge')) }
      notifies :extract, "archive_file[#{cni_tgz}]", :immediately
    end

    archive_file cni_tgz do
      destination new_resource.cni_path
      overwrite false
      action :nothing
    end

    # Sysctl settings for container/bridge networking
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

  ruby_block 'read_consul_agent_token' do
    block do
      require 'json'
      p = '/opt/consul/acl-tokens.json'
      raise 'Consul agent token file missing' unless ::File.exist?(p)
      tok = JSON.parse(::File.read(p))['agent']
      raise 'Consul agent token empty' if tok.to_s.empty?
      node.run_state['consul_agent_token'] = tok
    end
  end 

  # ------------------------------------------------------------------
  # Render Nomad configuration (HCL)
  # Pass retry_join and Vault token as template variables; others via node attrs
  # ------------------------------------------------------------------
  template ::File.join(new_resource.config_dir, 'nomad.hcl') do
    source 'config.hcl.erb'
    owner  new_resource.user
    group  new_resource.group
    mode   '0640'
    sensitive true
    variables(
      consul_token: lazy { node.run_state['consul_agent_token'] },
      server_enabled: new_resource.server_enabled,
      retry_join: new_resource.retry_join,
      token: new_resource.vault_token || ''
    )
    notifies :restart, 'service[nomad]', :delayed
  end

  # ------------------------------------------------------------------
  # Systemd unit (hardened) — single control point for service state
  # ------------------------------------------------------------------
  service 'nomad' do
    action :nothing
  end

  systemd_unit 'nomad.service' do
    content(
      <<~UNIT
        [Unit]
        Description=nomad Agent
        Documentation=https://www.nomad.io/
        Requires=network-online.target
        After=network-online.target

        [Service]
        User=#{new_resource.user}
        Group=#{new_resource.group}
        ExecStartPre=/bin/chown -R #{new_resource.user}:#{new_resource.group} #{new_resource.data_dir}
        ExecStart=/usr/local/bin/nomad agent -config=#{new_resource.config_dir}
        Restart=on-failure
        RestartSec=2
        LimitNOFILE=1048576
        LimitNPROC=infinity
        TasksMax=infinity

        [Install]
        WantedBy=multi-user.target
      UNIT
    )
    action [:create, :enable]
    notifies :enable, 'service[nomad]', :immediately
    notifies :restart, 'service[nomad]', :immediately
  end
end
