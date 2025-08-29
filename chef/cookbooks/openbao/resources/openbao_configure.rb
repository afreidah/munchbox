# frozen_string_literal: true

# -----------------------------------------------------------------------------
# Cookbook:: openbao
# Resource:: openbao_configure
#
# Manages TLS material, config file, and directories for OpenBao (no cloud deps).
# -----------------------------------------------------------------------------

unified_mode true
provides :openbao_configure

# --- Properties ---
property :config_path,      String, default: '/etc/openbao/openbao.hcl'
property :template_source,  String, default: 'openbao.hcl.erb'
property :storage_path,     String, default: '/opt/openbao/data'
property :node_id,          String, name_property: false
property :hostname,         String, required: true

# TLS: paths to already-provisioned certs/keys/CA bundle
property :tls_cert,         String, required: true
property :tls_key,          String, required: true
property :tls_ca,           String, required: true

# Service/user/dirs
property :service_user,     String, default: 'openbao'
property :service_group,    String, default: 'openbao'
property :service_name,     String, default: 'openbao'
property :config_dir,       String, default: '/etc/openbao'
property :log_dir,          String, default: '/var/log'
property :data_dir,         String, default: '/opt/openbao'

action :create do
  # --- Ensure dirs exist ---
  [new_resource.config_dir, new_resource.data_dir, ::File.dirname(new_resource.config_path)].uniq.each do |d|
    directory d do
      owner new_resource.service_user
      group new_resource.service_group
      mode '0750'
      recursive true
    end
  end

  directory ::File.join(new_resource.log_dir) do
    mode '0755'
  end

  # --- Config file from template ---
  template new_resource.config_path do
    source new_resource.template_source
    cookbook new_resource.cookbook_name.to_s
    owner new_resource.service_user
    group new_resource.service_group
    mode '0640'
    variables(
      storage_path: new_resource.storage_path,
      node_id:      new_resource.node_id || new_resource.hostname,
      hostname:     new_resource.hostname,
      tls_cert:     new_resource.tls_cert,
      tls_key:      new_resource.tls_key,
      tls_ca:       new_resource.tls_ca
    )
    sensitive true
  end
end
