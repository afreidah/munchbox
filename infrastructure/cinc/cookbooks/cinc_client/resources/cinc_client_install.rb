# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Resource:: cinc_client_install
#
# Installs the cinc-client .deb directly from packages.cinc.sh.
#
# We deliberately do NOT use the cinc-project packagecloud apt repo --
# packagecloud's auto-generated config tells you a URL that doesn't
# exist (every codename across stable/current/unstable returns 404 as
# of 2026-05). Direct .deb download from the canonical release server
# mirrors how the consul / nomad cookbooks fetch their binaries.
#
# URL shape:
#   https://packages.cinc.sh/files/stable/cinc/<version>/<platform>/<release>/cinc_<version>-1_<arch>.deb
#
# Properties:
#   version       - Pinned version, e.g. '19.2.12' (required).
#   package_name  - Apt package name; used for dpkg_package + idempotency
#                   check. Default 'cinc'.
#   download_base - Base URL; override only for a private mirror.
#   channel       - 'stable' / 'current' / 'unstable'. Default 'stable'.
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_client_install

property :version,       String, required: true
property :package_name,  String, default: 'cinc'
property :download_base, String, default: 'https://packages.cinc.sh/files'
property :channel,       String, default: 'stable'

default_action :install

# --- Per-platform/arch URL derivation lives in the action_class so both actions can reuse ---
action_class do
  def arch
    case node['kernel']['machine']
    when 'aarch64', 'arm64' then 'arm64'
    else 'amd64'
    end
  end

  def deb_name(version)
    "cinc_#{version}-1_#{arch}.deb"
  end

  def download_url(version)
    [
      new_resource.download_base,
      new_resource.channel,
      'cinc',
      version,
      node['platform'],
      node['platform_version'],
      deb_name(version),
    ].join('/')
  end
end

# -------------------------------------------------------------------------------
# Action :install  --  Fetch the .deb only when local cinc version differs, then dpkg install
# -------------------------------------------------------------------------------

action :install do
  deb_path = "/var/cache/#{deb_name(new_resource.version)}"

  # --- Stale cinc-project apt repo from the ansible bootstrap; packagecloud returns 404 on every codename, generates apt warnings on every run. Drop it -- we install from downloads.cinc.sh now. ---
  file '/etc/apt/sources.list.d/cinc-project.list' do
    action :delete
  end

  # --- The dpkg_package only fires when remote_file actually downloads (i.e. when the local version isn't already the pinned one); otherwise both are no-ops. ---
  remote_file deb_path do
    source download_url(new_resource.version)
    owner  'root'
    group  'root'
    mode   '0644'
    not_if "dpkg-query -W -f='${Version}' #{new_resource.package_name} 2>/dev/null | grep -q '^#{new_resource.version}-1$'"
    notifies :install, "dpkg_package[#{new_resource.package_name}]", :immediately
  end

  dpkg_package new_resource.package_name do
    source  deb_path
    version "#{new_resource.version}-1"
    action  :nothing
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
