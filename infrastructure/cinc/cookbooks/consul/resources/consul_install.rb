# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Resource:: consul_install
#
# Installs the consul binary from HashiCorp's release archive (the
# munchbox apt repo doesn't carry it). Lays down the system user, group,
# and standard directory layout if they don't already exist
# (vault-cert-manager may have created the user + tls dir before this
# resource runs -- idempotent in both cases), then hands the download +
# SHA256SUMS verification + extraction to munchbox_lib_artifact. consul
# is bounced on a real version change via the shared service subscribe.
#
# Properties:
#   version    - consul version string (e.g. '1.22.7'); used to build the
#                download URL + to detect drift via `consul version`.
#   bin_path   - Where to install the binary (default /usr/local/bin/consul).
#   user/group - System user/group consul runs as.
#   config_dir - /etc/consul.d (holds consul.hcl + tls/).
#   data_dir   - Raft + state storage.
#   tls_dir    - Where vault-cert-manager drops certs; consul.hcl points here.
#   log_dir    - File log target (consul itself logs to journald by default;
#                this dir exists for ops convenience / future log file).
# -------------------------------------------------------------------------------

unified_mode true

provides :consul_install

property :version,    String, required: true
property :bin_path,   String, default: '/usr/local/bin/consul'
property :user,       String, default: 'consul'
property :group,      String, default: 'consul'
property :config_dir, String, default: '/etc/consul.d'
property :data_dir,   String, default: '/opt/consul/data'
property :tls_dir,    String, default: '/etc/consul.d/tls'
property :log_dir,    String, default: '/var/log/consul'

default_action :install

# --- arch detection (arm64 for Pi5/oracle-arm, amd64 elsewhere); URL + SHA256SUMS come from the shared HashiCorp helpers ---
action_class do
  def arch
    MunchboxLibCookbook::Artifact.normalize_arch(node['kernel']['machine'])
  end
end

# -------------------------------------------------------------------------------
# Action :install
# -------------------------------------------------------------------------------

action :install do
  # --- setup users, groups, and directories ---
  group new_resource.group do
    system true
  end

  user new_resource.user do
    group new_resource.group
    system true
    shell '/bin/false'
    home new_resource.data_dir
    manage_home false
  end

  # --- setup required consul directories ---
  [new_resource.config_dir, new_resource.data_dir, new_resource.tls_dir, new_resource.log_dir].each do |d|
    directory d do
      owner     new_resource.user
      group     new_resource.group
      mode      '0750'
      recursive true
    end
  end

  version     = new_resource.version
  drift_guard = "test -x #{new_resource.bin_path} && #{new_resource.bin_path} version | grep -q 'Consul v#{version}'"

  # --- install consul with the shared munchbox_lib_artifact resource ---
  munchbox_lib_artifact "consul #{version}" do
    source           MunchboxLibCookbook::Artifact.hashicorp_url('consul', version, arch)
    sums_url         MunchboxLibCookbook::Artifact.hashicorp_sums_url('consul', version)
    format           :zip
    bin_dir          ::File.dirname(new_resource.bin_path)

    # --- guards and notifications ---
    not_if_installed drift_guard
    notifies :restart, 'service[consul]', :delayed
  end

  # --- Shadow service declaration so the notify above resolves inside this resource's collection (unified_mode sandboxes notify lookups per-action). ---
  service 'consul' do
    action :nothing
  end

  # --- Setup systemd service script ---
  systemd_unit 'consul.service' do
    content <<~UNIT
      [Unit]
      Description=Consul Agent
      Documentation=https://www.consul.io/docs/
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=#{new_resource.config_dir}/consul.hcl

      [Service]
      Type=notify
      User=#{new_resource.user}
      Group=#{new_resource.group}
      ExecStart=#{new_resource.bin_path} agent -config-dir=#{new_resource.config_dir}
      ExecReload=/bin/kill --signal HUP $MAINPID
      KillMode=process
      KillSignal=SIGTERM
      Restart=on-failure
      RestartSec=5
      LimitNOFILE=65536

      [Install]
      WantedBy=multi-user.target
    UNIT
    action :create
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Remove binary only -- leaves user/dirs/data alone for safety
# -------------------------------------------------------------------------------

action :remove do
  file new_resource.bin_path do
    action :delete
  end
end
