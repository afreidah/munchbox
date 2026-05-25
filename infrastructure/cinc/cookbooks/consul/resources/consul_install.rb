# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Resource:: consul_install
#
# Installs the consul binary from HashiCorp's release archive (the
# munchbox apt repo doesn't carry it). Also lays down the system user,
# group, and standard directory layout if they don't already exist
# (vault-cert-manager may have created the user + tls dir before this
# resource runs -- idempotent in both cases).
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

# --- Download URL + arch detection (arm64 for Pi5/oracle-arm, amd64 elsewhere) ---
action_class do
  def arch
    case node['kernel']['machine']
    when 'aarch64', 'arm64' then 'arm64'
    else 'amd64'
    end
  end

  def archive_name(version)
    "consul_#{version}_linux_#{arch}.zip"
  end

  def download_url(version)
    "https://releases.hashicorp.com/consul/#{version}/#{archive_name(version)}"
  end
end

# -------------------------------------------------------------------------------
# Action :install  --  Ensure user/group/dirs, then install the binary only when version differs
# -------------------------------------------------------------------------------

action :install do
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

  [new_resource.config_dir, new_resource.data_dir, new_resource.tls_dir, new_resource.log_dir].each do |d|
    directory d do
      owner     new_resource.user
      group     new_resource.group
      mode      '0750'
      recursive true
    end
  end

  # --- unzip is the only system-level prereq for extracting the archive ---
  package 'unzip'

  archive_path = "/tmp/#{archive_name(new_resource.version)}"

  remote_file archive_path do
    source   download_url(new_resource.version)
    mode     '0644'
    not_if   "test -x #{new_resource.bin_path} && #{new_resource.bin_path} version | grep -q 'Consul v#{new_resource.version}'"
  end

  # --- Render the systemd unit here, not in configure. The unit content is static deployment plumbing (binary path, user/group, config dir) -- no dynamic Vault state -- so it belongs with install. Single source of truth: configure declares no systemd_unit, just starts service[consul]. Greenfield ordering works because the unit file lands BEFORE the binary-install execute's restart notify fires. ConditionFileNotEmpty on consul.hcl makes the unit a no-op start until configure renders the config. ---
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

  # --- Shadow service declaration so the version-bump notify below resolves inside this custom resource's collection (unified_mode true sandboxes notify lookups per-action). ---
  service 'consul' do
    action :nothing
  end

  execute "install consul #{new_resource.version}" do
    command "unzip -o #{archive_path} -d /usr/local/bin && chmod 0755 #{new_resource.bin_path} && rm -f #{archive_path}"
    not_if  "test -x #{new_resource.bin_path} && #{new_resource.bin_path} version | grep -q 'Consul v#{new_resource.version}'"
    # --- Bounce consul after a version change so the running process actually uses the new binary. Unit file is rendered above first, so the restart resolves cleanly even on greenfield. ---
    notifies :restart, 'service[consul]', :delayed
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
