# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  attributes/global.rb — Global general attributes
#
#  Defines global attributes used by the install recipe for OpenBao.
# ------------------------------------------------------------------------------

# --- Switch for turning on/off sensitive resources for debugging ---
default['global']['sensitive'] = false

# --- Override for including base_server::role if you are using a custom image ---
default['global']['packer_image'] = false

# --- Directory for Sentinel files ---
default['global']['sentinel_dir'] = '/usr/local/sentinel'
