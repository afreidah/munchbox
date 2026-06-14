# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Resource:: cinc_client_install
#
# Installs the cinc-client .deb directly from packages.cinc.sh, delegating the
# download/checksum-verify/install to munchbox_lib_artifact. We deliberately do
# NOT use the cinc-project packagecloud apt repo -- packagecloud's auto-generated
# config tells you a URL that doesn't exist (every codename across
# stable/current/unstable returns 404 as of 2026-05).
#
# URL shape:
#   <base>/<channel>/cinc/<version>/<platform>/<release>/cinc_<version>-1_<arch>.deb
#
# Properties:
#   version       - Pinned version, e.g. '19.3.14' (required).
#   package_name  - Apt package name; used for dpkg + idempotency. Default 'cinc'.
#   download_base - Base URL; override only for a private mirror.
#   channel       - 'stable' / 'current' / 'unstable'. Default 'stable'.
#   checksums     - { "<platform>/<release>" => { "<arch>" => sha256 } }; cinc
#                   publishes no SHA256SUMS, so the sha is pinned per version.
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_client_install

property :version,       String, required: true
property :package_name,  String, default: 'cinc'
property :download_base, String, default: 'https://packages.cinc.sh/files'
property :channel,       String, default: 'stable'
property :checksums,     Hash, default: {}

default_action :install

# --- Per-platform/arch URL + checksum derivation; trivial enough to stay here ---
action_class do
  def arch
    MunchboxLibCookbook::Artifact.normalize_arch(node['kernel']['machine'])
  end

  # --- cinc serves debian under the MAJOR version only (/debian/12/), but Ohai
  #     reports the point release (12.12); ubuntu uses the full version ---
  def url_platform_version
    platform?('debian') ? node['platform_version'].to_i.to_s : node['platform_version']
  end

  def deb_name(version)
    "cinc_#{version}-1_#{arch}.deb"
  end

  def download_url(version)
    [
      new_resource.download_base, new_resource.channel, 'cinc', version,
      node['platform'], url_platform_version, deb_name(version)
    ].join('/')
  end

  # --- pinned sha256 for this platform/release/arch; fail closed ---
  def pinned_checksum
    key = "#{node['platform']}/#{url_platform_version}"
    new_resource.checksums.dig(key, arch) ||
      raise("cinc_client_install: no pinned sha256 for #{key} #{arch} (add it to node['cinc_client']['install']['checksums'])")
  end
end

# -------------------------------------------------------------------------------
# Action :install  --  Drop the stale apt source, then download-verify-install the .deb
# -------------------------------------------------------------------------------

action :install do
  version = new_resource.version

  # --- Stale cinc-project apt repo from the ansible bootstrap; packagecloud 404s on every codename. Drop it -- we install from packages.cinc.sh now. ---
  file '/etc/apt/sources.list.d/cinc-project.list' do
    action :delete
  end

  munchbox_lib_artifact "cinc #{version}" do
    source           download_url(version)
    format           :deb
    checksum         pinned_checksum
    package_name     new_resource.package_name
    package_version  "#{version}-1"
    not_if_installed "dpkg-query -W -f='${Version}' #{new_resource.package_name} 2>/dev/null | grep -q '^#{version}-1$'"
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Purge the cinc package
# -------------------------------------------------------------------------------

action :remove do
  dpkg_package new_resource.package_name do
    action :purge
  end
end
