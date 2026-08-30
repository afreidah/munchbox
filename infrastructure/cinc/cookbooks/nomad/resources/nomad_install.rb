# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_install
#
# Installs the nomad binary from HashiCorp's release archive (no apt
# repo). Creates the system user, group, and standard directory layout
# if they don't already exist (vault-cert-manager may have created the
# user + tls dir before this resource runs -- idempotent in both cases).
#
# Properties:
#   version    - nomad version string (e.g. '1.11.1'); used to build the
#                download URL + to detect drift via `nomad version`.
#   bin_path   - install location (default /usr/local/bin/nomad).
#   user/group - System user/group nomad runs as.
#   config_dir - /etc/nomad.d (holds nomad.hcl + tls/).
#   data_dir   - Allocations + state storage.
#   log_dir    - File log target (nomad logs to journald by default;
#                this dir exists for ops convenience / future log file).
# -------------------------------------------------------------------------------

unified_mode true

provides :nomad_install

property :version,    String, required: true
property :bin_path,   String, default: '/usr/local/bin/nomad'
# --- Default to root for parity with the existing ansible-managed agents; their /var/lib/nomad state trees are root-owned. ---
property :user,       String, default: 'root'
property :group,      String, default: 'root'
property :config_dir, String, default: '/etc/nomad.d'
property :data_dir,   String, default: '/var/lib/nomad'
property :log_dir,    String, default: '/var/log/nomad'

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Ensure user/group/dirs, then install the binary only when version differs
# -------------------------------------------------------------------------------

action :install do
  # --- Skip user/group creation when running as root -- root always exists, and creating a vestigial nomad user just confuses ops ---
  unless new_resource.user == 'root'
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
  end

  # --- dirs + release-zip install + drift-only restart, shared with consul/vault ---
  munchbox_lib_hashicorp_install 'nomad' do
    version  new_resource.version
    bin_path new_resource.bin_path
    dirs     [new_resource.config_dir, new_resource.data_dir, new_resource.log_dir]
    owner    new_resource.user
    group    new_resource.group
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
