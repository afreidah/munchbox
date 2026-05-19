# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Recipe:: bootstrap
#
# Creates the initial org + admin user so the server is actually usable
# from `knife`. Both resources are idempotent (org-show / user-show
# gating), so this recipe is safe to leave in every converge.
# -------------------------------------------------------------------------------

cinc_server_org node[cookbook]['bootstrap']['org']['short_name'] do
  full_name node[cookbook]['bootstrap']['org']['full_name']
end

cinc_server_user node[cookbook]['bootstrap']['user']['username'] do
  first_name node[cookbook]['bootstrap']['user']['first_name']
  last_name  node[cookbook]['bootstrap']['user']['last_name']
  email      node[cookbook]['bootstrap']['user']['email']
  password   node[cookbook]['bootstrap']['user']['password']
  key_path   node[cookbook]['bootstrap']['user']['key_path']
  org        node[cookbook]['bootstrap']['org']['short_name']
end
