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

# --- arch detection (arm64 for Pi5/oracle-arm, amd64 elsewhere); URL + SHA256SUMS come from the shared HashiCorp helpers ---
action_class do
  def arch
    MunchboxLibCookbook::Artifact.normalize_arch(node['kernel']['machine'])
  end
end

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

  [new_resource.config_dir, new_resource.data_dir, new_resource.log_dir].each do |d|
    directory d do
      owner     new_resource.user
      group     new_resource.group
      mode      '0750'
      recursive true
    end
  end

  version     = new_resource.version
  drift_guard = "test -x #{new_resource.bin_path} && #{new_resource.bin_path} version | grep -q 'Nomad v#{version}'"

  # --- Download the release zip, verify against HashiCorp's published SHA256SUMS, and extract to bin_dir -- all skipped when the installed version already matches. ---
  munchbox_lib_artifact "nomad #{version}" do
    source           MunchboxLibCookbook::Artifact.hashicorp_url('nomad', version, arch)
    sums_url         MunchboxLibCookbook::Artifact.hashicorp_sums_url('nomad', version)
    format           :zip
    bin_dir          ::File.dirname(new_resource.bin_path)
    not_if_installed drift_guard
    # --- Bounce nomad only when the artifact actually re-installed (drift). ---
    notifies :restart, 'service[nomad]', :delayed
  end

  # --- Shadow service declaration so the notify above resolves inside this resource's collection (unified_mode sandboxes notify lookups per-action; we can't notify the configure recipe's systemd_unit[nomad.service] across that boundary). ---
  service 'nomad' do
    action :nothing
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
