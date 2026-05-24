# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_packages
#
# Installs (or removes) a set of apt packages. Used by the recipe to ship the
# baseline package set every node needs; also reusable from other cookbooks
# that want to declare their own package list against the same resource.
#
# Properties:
#   packages - Array of package names (required).
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_packages

property :packages, Array, required: true

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Ensure every named package is installed
# -------------------------------------------------------------------------------

action :install do
  package new_resource.name do
    package_name new_resource.packages
    action       :install
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Purge every named package (use with care)
# -------------------------------------------------------------------------------

action :remove do
  package new_resource.name do
    package_name new_resource.packages
    action       :remove
  end
end
