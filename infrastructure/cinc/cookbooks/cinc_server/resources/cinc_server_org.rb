# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Resource:: cinc_server_org
#
# Idempotently creates an organization via `chef-server-ctl org-create`.
# `org-show` is the existence check -- exits 0 if present, non-zero if not.
#
# Properties:
#   short_name - Org slug used in API paths (default: resource name).
#   full_name  - Human-readable org name (required).
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_server_org

property :short_name, String, name_property: true
property :full_name,  String, required: true

default_action :create

# --- Create the org if it doesn't already exist ---
action :create do
  execute "chef-server-ctl org-create #{new_resource.short_name}" do
    command "chef-server-ctl org-create '#{new_resource.short_name}' '#{new_resource.full_name}'"
    environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
    not_if "chef-server-ctl org-show '#{new_resource.short_name}'"
  end
end

# --- Tear an org down (rarely useful; mostly for test cleanup) ---
action :delete do
  execute "chef-server-ctl org-delete #{new_resource.short_name}" do
    command "chef-server-ctl org-delete '#{new_resource.short_name}' --yes"
    environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
    only_if "chef-server-ctl org-show '#{new_resource.short_name}'"
  end
end
