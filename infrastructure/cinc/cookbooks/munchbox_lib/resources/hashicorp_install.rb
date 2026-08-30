# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Resource:: hashicorp_install
#
# The install half that consul, nomad and vault all share: own the service
# directories, then hand the release zip to munchbox_lib_artifact guarded on a
# version-drift check, and bounce the service only when the artifact actually
# re-installed.
#
# Each of the three had its own verbatim copy of this. They are deliberately
# identical -- the only real differences are the product name and which
# directories it owns -- so the copies were duplication rather than divergence.
#
# The caller keeps whatever is genuinely its own: user/group creation, extra
# group memberships, and the systemd unit.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_lib_hashicorp_install

# --- consul | nomad | vault; also the artifact name and the default service ---
property :product, String, name_property: true

property :version,  String, required: true
property :bin_path, String, required: true

# --- Directories the service owns, created 0750 owner:group ---
property :dirs, Array, default: []

property :owner, String, required: true
property :group, String, required: true

# --- Defaults to product; set it when the systemd unit is named differently ---
property :service_name, String

default_action :install

# --- arch detection (arm64 for Pi5/oracle-arm, amd64 elsewhere); URL + SHA256SUMS come from the shared HashiCorp helpers ---
action_class do
  def arch
    MunchboxLibCookbook::Artifact.normalize_arch(node['kernel']['machine'])
  end
end

action :install do
  new_resource.dirs.each do |d|
    directory d do
      owner     new_resource.owner
      group     new_resource.group
      mode      '0750'
      recursive true
    end
  end

  product = new_resource.product
  version = new_resource.version
  svc     = new_resource.service_name || product

  # --- `<binary> version` prints "Consul v1.2.3" / "Nomad v1.2.3" / "Vault v1.2.3" ---
  drift_guard = "test -x #{new_resource.bin_path} && " \
                "#{new_resource.bin_path} version | grep -q '#{product.capitalize} v#{version}'"

  # --- Download, verify against HashiCorp's published SHA256SUMS, extract -- all skipped when the installed version already matches. ---
  munchbox_lib_artifact "#{product} #{version}" do
    source           MunchboxLibCookbook::Artifact.hashicorp_url(product, version, arch)
    sums_url         MunchboxLibCookbook::Artifact.hashicorp_sums_url(product, version)
    format           :zip
    bin_dir          ::File.dirname(new_resource.bin_path)
    not_if_installed drift_guard
    # --- Bounce only on real drift, never on a no-op converge. ---
    notifies         :restart, "service[#{svc}]", :delayed
  end

  # --- Shadow service declaration so the notify above resolves inside this resource's collection (unified_mode sandboxes notify lookups per-action; we can't notify the configure recipe's systemd_unit across that boundary). ---
  service svc do
    action :nothing
  end
end
