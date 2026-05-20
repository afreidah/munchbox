# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Resource:: cinc_client_install
#
# Registers the cinc-project apt repo and installs the cinc package at
# the pinned version. Defaults to cinc's packagecloud repo; override
# uri/key to switch to an internal mirror or chef-io.
#
# Properties:
#   version      - Pinned version, e.g. '19.2.12' (required).
#   package_name - apt package name (required, e.g. `cinc`).
#   apt_repo_uri - Base URL of the apt repo (required).
#   apt_repo_key - URL of the ascii-armoured signing key (required).
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_client_install

property :version,      String, required: true
property :package_name, String, required: true
property :apt_repo_uri, String, required: true
property :apt_repo_key, String, required: true

default_action :install

# --- Register cinc-project apt repo + install the cinc package ---
action :install do
  # --- Block on apt's frontend/lists lock so unattended-upgrades / apt-daily timers don't race the run ---
  munchbox_base_apt_lock_wait 'cinc_client_install'

  # --- Refresh apt cache; cloud images ship with stale indexes that 404 on version-pinned installs ---
  apt_update 'cinc_client_install' do
    action :periodic
  end

  # --- apt_repository shells out to gpg + needs https transport at compile time ---
  package %w(gnupg apt-transport-https ca-certificates) do
    action :install
  end

  apt_repository 'cinc-project' do
    uri          new_resource.apt_repo_uri
    components   %w(main)
    key          new_resource.apt_repo_key
    action       :add
  end

  apt_package new_resource.package_name do
    version "#{new_resource.version}-1"
    action  :install
  end
end

# --- Remove the package; leave the repo registered ---
action :remove do
  apt_package new_resource.package_name do
    action :remove
  end
end
