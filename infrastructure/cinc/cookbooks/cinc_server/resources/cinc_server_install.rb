# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Resource:: cinc_server_install
#
# Downloads the Chef Infra Server omnibus .deb to /var/cache and installs
# it via dpkg_package. Defaults install cinc-server-core from
# downloads.cinc.sh; overriding url/version/package_name flips the
# cookbook to upstream chef-server-core or any compatible build without
# touching the resource code.
#
# Properties:
#   url          - Full URL to the .deb (required).
#   version      - Pinned version string (required) -- used to gate dpkg_package
#                  upgrades and to disambiguate the cached download path.
#   checksum     - Optional SHA256. When set, remote_file enforces it and
#                  skips re-download if the cached file matches.
#   package_name - dpkg package name to install/remove (required, e.g.
#                  cinc-server-core or chef-server-core).
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_server_install

property :url,          String, required: true
property :version,      String, required: true
property :checksum,     [String, nil]
property :package_name, String, required: true

default_action :install

# --- Fetch the .deb if needed and dpkg-install at the pinned version ---
action :install do
  # --- infra-server::log_cleanup writes to /etc/cron.hourly; Debian 12 cloud image needs cron installed first ---
  package 'cron' do
    action :install
  end

  cache_path = "/var/cache/#{new_resource.package_name}-#{new_resource.version}.deb"

  remote_file cache_path do
    source   new_resource.url
    checksum new_resource.checksum if new_resource.checksum
    owner    'root'
    group    'root'
    mode     '0644'
    action   :create
  end

  dpkg_package new_resource.package_name do
    source  cache_path
    version "#{new_resource.version}-1"
    action  :install
  end
end

# --- Remove the package; leave the cached .deb alone in case we're reinstalling ---
action :remove do
  dpkg_package new_resource.package_name do
    action :remove
  end
end
