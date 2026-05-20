# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_apt_repo
#
# Registers an apt repository + signing key. Designed for the in-house aptly
# repo at apt.munchbox.cc but takes uri/distribution/components/key_url so
# any cookbook that needs another apt repo can reuse the resource.
#
# Properties:
#   uri          - Base URL of the repo (required).
#   distribution - Suite, e.g. 'stable'.
#   components   - Array of components, e.g. %w(main).
#   key_url      - URL of the ASCII-armoured signing key (optional but
#                  effectively required for any modern repo).
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_apt_repo

property :uri,          String, required: true
property :distribution, String, default: 'stable'
property :components,   Array,  default: %w(main)
property :key_url,      String

default_action :configure

# --- Add the repo + key (apt_repository runs apt-get update internally) ---
action :configure do
  # --- Block on apt's frontend/lists lock so unattended-upgrades / apt-daily timers don't race the run ---
  munchbox_base_apt_lock_wait 'munchbox_base_apt_repo'

  # Refresh the cache first -- stock cloud images often ship with an apt
  # index pinned to a debian point release that has since rolled forward,
  # so explicit version installs (gnupg, apt-transport-https) 404 against
  # the live mirror until `apt-get update` runs. `:periodic` keeps this
  # idempotent across converges (only refreshes if the cache is older
  # than `frequency` seconds, default 1 day).
  apt_update 'munchbox_base_apt_repo' do
    action :periodic
  end

  # apt_repository shells out to `gpg` to verify the signing key + may need
  # https transport for the apt_repository fetch. Ensure both are present
  # before the repository resource runs.
  package %w(gnupg apt-transport-https ca-certificates) do
    action :install
  end

  apt_repository new_resource.name do
    uri          new_resource.uri
    distribution new_resource.distribution
    components   new_resource.components
    key          new_resource.key_url if new_resource.key_url
    action       :add
  end
end

# --- Remove the repo from sources.list.d ---
action :remove do
  apt_repository new_resource.name do
    action :remove
  end
end
