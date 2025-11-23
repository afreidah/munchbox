# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  Resource: consul_service — Manages Consul systemd unit and service
# ------------------------------------------------------------------------------

unified_mode true

property :user,        String, required: true
property :group,       String, required: true
property :data_dir,    String, required: true
property :config_dir,  String, required: true
property :install_dir, String, required: true

# ------------------------------------------------------------------------------
#  Action: :create — Renders and enables Consul systemd unit
# ------------------------------------------------------------------------------

action :create do
  consul_binary = ::File.join(new_resource.install_dir, 'consul')

  # --- Systemd: Daemon Reload Trigger ---
  execute 'systemctl-daemon-reload' do
    command 'systemctl daemon-reload'
    action  :nothing
    only_if { ::File.exist?('/run/systemd/system') }
  end

  # --- Render Consul systemd Unit ---
  systemd_unit 'consul.service' do
    content(
      'Unit' => {
        'Description' => 'Consul Agent',
        'Documentation' => 'https://www.consul.io/',
        'Wants' => 'network-online.target',
        'After' => 'network-online.target',
      },
      'Service' => {
        'User' => new_resource.user,
        'Group' => new_resource.group,
        'ExecStartPre' => [
          "/bin/mkdir -p #{new_resource.data_dir}",
          "/bin/chown -R #{new_resource.user}:#{new_resource.group} #{new_resource.data_dir}",
        ],
        'ExecStart' => "#{consul_binary} agent -config-dir=#{new_resource.config_dir}",
        'ExecReload' => '/bin/kill --signal HUP $MAINPID',
        'KillMode' => 'process',
        'Restart' => 'on-failure',
        'RestartSec' => '2',
        'LimitNOFILE' => '65536',
      },
      'Install' => {
        'WantedBy' => 'multi-user.target',
      }
    )
    action   [:create, :enable]
    notifies :run, 'execute[systemctl-daemon-reload]', :immediately
    only_if { ::File.exist?('/run/systemd/system') }
  end

  # --- Render Consul init.d Script for non-systemd ---
  template '/etc/init.d/consul' do
    source 'consul-init.erb'
    mode '0755'
    owner node['consul']['user']
    group node['consul']['group']
    variables(
      consul_binary: consul_binary,
      config_dir: new_resource.config_dir,
      data_dir: new_resource.data_dir,
      user: new_resource.user,
      group: new_resource.group
    )
    not_if { ::File.exist?('/run/systemd/system') }
  end

  service 'consul' do
    action [:enable, :start]
  end
end

# ------------------------------------------------------------------------------
#  Action: :delete — Removes Consul systemd unit
# ------------------------------------------------------------------------------

action :delete do
  systemd_unit 'consul.service' do
    action [:disable, :delete]
  end
end
