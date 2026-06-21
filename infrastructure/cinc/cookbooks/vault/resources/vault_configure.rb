# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault
# Resource:: vault_configure
#
# Drops /etc/vault.d/vault.hcl + the vault.service systemd unit. Does
# NOT restart vault on config change by default (shamir-sealed; restart
# = manual unseal x3). The `restart_on_change` property lets an
# operator opt in during a planned maintenance window.
#
# Sweep list (`stale_paths`) deletes ansible-era leftovers: vault.hcl.bak,
# .pre-tls.<epoch>, .bak.<date>, etc.
# -------------------------------------------------------------------------------

unified_mode true

provides :vault_configure

# --- Identity / cluster ---
property :node_name,        String, required: true
property :advertise_ip,     String, required: true
property :cluster_name,     String, default: 'munchbox-vault'
property :log_level,        String, default: 'info'
property :ui_enabled,       [true, false], default: true
property :disable_mlock,    [true, false], default: false

# --- Listener ---
property :listener_address,        String,        default: '0.0.0.0:8200'
property :listener_tls_disable,    [true, false], default: false
property :listener_tls_cert_file,  String,        default: '/etc/vault.d/tls/vault.crt'
property :listener_tls_key_file,   String,        default: '/etc/vault.d/tls/vault.key'

# --- Cluster addrs ---
property :api_scheme,    String,  default: 'https'
property :api_port,      Integer, default: 8200
property :cluster_port,  Integer, default: 8201

# --- Storage (consul) ---
property :storage_address,       String, default: '127.0.0.1:8501'
property :storage_scheme,        String, default: 'https'
property :storage_path,          String, default: 'vault/'
property :storage_tls_ca_file,   String, default: '/etc/consul.d/tls/ca-chain.crt'
property :storage_tls_cert_file, String, default: '/etc/consul.d/tls/consul.crt'
property :storage_tls_key_file,  String, default: '/etc/consul.d/tls/consul.key'
property :consul_storage_token,  [String, nil], sensitive: true

# --- Service registration ---
property :service_registration_enabled, [true, false], default: true

# --- Telemetry ---
property :telemetry_disable_hostname,          [true, false], default: false
property :telemetry_prometheus_retention_time, String,        default: '30s'
property :telemetry_usage_gauge_period,        String,        default: '10m'
property :telemetry_enable_hostname_label,     [true, false], default: true

# --- Daemon plumbing ---
property :bin_path,    String, default: '/usr/local/bin/vault'
property :config_dir,  String, default: '/etc/vault.d'
property :user,        String, default: 'vault'
property :group,       String, default: 'vault'

# --- Safety knobs ---
# By default we render config + systemd unit but DO NOT restart vault on
# changes. Set true only when an operator is standing by to unseal x3.
property :restart_on_change, [true, false], default: false

property :stale_paths,       Array, default: []

# --- Seal (OCI KMS auto-unseal); disabled unless the role enables it ---
property :seal_enabled,             [true, false], default: false
property :seal_key_id,              [String, nil]
property :seal_crypto_endpoint,     [String, nil]
property :seal_management_endpoint, [String, nil]
property :oci_tenancy_ocid,         [String, nil]
property :oci_user_ocid,            [String, nil]
property :oci_fingerprint,          [String, nil]
property :oci_region,               [String, nil]
property :oci_config_dir,           String,        default: '/opt/vault/data/.oci'
property :oci_private_key_file,     String,        default: '/opt/vault/data/.oci/oci_api_key.pem'
property :oci_private_key,          [String, nil], sensitive: true

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  raise "vault_configure[#{new_resource.name}]: consul_storage_token cannot be empty" if new_resource.consul_storage_token.to_s.empty?

  # --- Sweep ansible-era leftovers (vault.hcl.bak / .pre-tls.* / .bak.<date>). ---
  new_resource.stale_paths.each do |path|
    file path do
      action :delete
    end
  end

  cfg = new_resource

  # --- OCI KMS auto-unseal: drop the API key + ~/.oci/config the seal reads (private key from the encrypted data bag) ---
  if cfg.seal_enabled
    raise "vault_configure[#{new_resource.name}]: seal_enabled but oci_private_key is empty" if cfg.oci_private_key.to_s.empty?

    directory cfg.oci_config_dir do
      owner     cfg.user
      group     cfg.group
      mode      '0700'
      recursive true
    end

    file cfg.oci_private_key_file do
      content   cfg.oci_private_key
      owner     cfg.user
      group     cfg.group
      mode      '0600'
      sensitive true
    end

    template "#{cfg.oci_config_dir}/config" do
      source   'oci_config.erb'
      cookbook 'vault'
      owner    cfg.user
      group    cfg.group
      mode     '0600'
      variables(
        user_ocid: cfg.oci_user_ocid,
        fingerprint: cfg.oci_fingerprint,
        tenancy_ocid: cfg.oci_tenancy_ocid,
        region: cfg.oci_region,
        private_key_file: cfg.oci_private_key_file
      )
    end
  end

  template "#{cfg.config_dir}/vault.hcl" do
    source 'vault.hcl.erb'
    cookbook 'vault'
    owner cfg.user
    group cfg.group
    mode  '0640'
    sensitive true
    variables(
      node_name: cfg.node_name,
      advertise_ip: cfg.advertise_ip,
      cluster_name: cfg.cluster_name,
      log_level: cfg.log_level,
      ui_enabled: cfg.ui_enabled,
      disable_mlock: cfg.disable_mlock,

      listener_address: cfg.listener_address,
      listener_tls_disable: cfg.listener_tls_disable,
      listener_tls_cert_file: cfg.listener_tls_cert_file,
      listener_tls_key_file: cfg.listener_tls_key_file,

      api_scheme: cfg.api_scheme,
      api_port: cfg.api_port,
      cluster_port: cfg.cluster_port,

      storage_address: cfg.storage_address,
      storage_scheme: cfg.storage_scheme,
      storage_path: cfg.storage_path,
      storage_tls_ca_file: cfg.storage_tls_ca_file,
      storage_tls_cert_file: cfg.storage_tls_cert_file,
      storage_tls_key_file: cfg.storage_tls_key_file,
      consul_storage_token: cfg.consul_storage_token,

      service_registration_enabled: cfg.service_registration_enabled,

      telemetry_disable_hostname: cfg.telemetry_disable_hostname,
      telemetry_prometheus_retention_time: cfg.telemetry_prometheus_retention_time,
      telemetry_usage_gauge_period: cfg.telemetry_usage_gauge_period,
      telemetry_enable_hostname_label: cfg.telemetry_enable_hostname_label,

      seal_enabled: cfg.seal_enabled,
      seal_key_id: cfg.seal_key_id,
      seal_crypto_endpoint: cfg.seal_crypto_endpoint,
      seal_management_endpoint: cfg.seal_management_endpoint
    )
    # --- Conditionally notify restart (default: NO). Operator opts in during planned maintenance. ---
    if cfg.restart_on_change
      notifies :restart, 'systemd_unit[vault.service]', :delayed
    end
  end

  # --- HOME = vault home so the OCI SDK finds ~/.oci/config ---
  systemd_unit 'vault.service' do
    content <<~UNIT
      [Unit]
      Description=HashiCorp Vault - Secrets Management
      Documentation=https://www.vaultproject.io/docs/
      Requires=network-online.target
      After=network-online.target
      ConditionFileNotEmpty=#{cfg.config_dir}/vault.hcl

      [Service]
      Type=notify
      User=#{cfg.user}
      Group=#{cfg.group}
      Environment=HOME=#{::File.dirname(cfg.oci_config_dir)}
      ProtectSystem=full
      ProtectHome=read-only
      PrivateTmp=yes
      PrivateDevices=yes
      SecureBits=keep-caps
      AmbientCapabilities=CAP_IPC_LOCK
      CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
      NoNewPrivileges=yes
      ExecStart=#{cfg.bin_path} server -config=#{cfg.config_dir}/vault.hcl
      ExecReload=/bin/kill --signal HUP $MAINPID
      KillMode=process
      KillSignal=SIGINT
      Restart=on-failure
      RestartSec=5
      TimeoutStopSec=30
      LimitNOFILE=65536
      LimitMEMLOCK=infinity

      [Install]
      WantedBy=multi-user.target
    UNIT
    action %i(create enable)
  end
end
