# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Recipe:: bootstrap
#
# Creates the initial org + admin user. Idempotent (org-show / user-show
# gates), so safe to leave in every converge.
#
# Admin password is fetched lazily from Vault (default
# secret/data/cinc-server/admin/alex, field `password`). An explicit
# attribute override still wins for break-glass / kitchen runs.
# -------------------------------------------------------------------------------

bootstrap = node[cookbook]['bootstrap']
paths     = node[cookbook]['vault_paths']

cinc_server_org bootstrap['org']['short_name'] do
  full_name bootstrap['org']['full_name']
end

cinc_server_user bootstrap['user']['username'] do
  first_name bootstrap['user']['first_name']
  last_name  bootstrap['user']['last_name']
  email      bootstrap['user']['email']
  # --- lazy{} defers to converge phase, after vault-agent has the token sink ready ---
  password(lazy { bootstrap['user']['password'] || vault_fetch(paths['admin_password']['path'], paths['admin_password']['field']) })
  key_path bootstrap['user']['key_path']
  org      bootstrap['org']['short_name']
end

# --- Non-human org members (CI). Same idempotent user-show gate as the admin,
#     so these are safe to leave in every converge. ---
bootstrap['extra_users'].each do |extra|
  vault_path = paths['extra_user_passwords'][extra['username']]

  cinc_server_user extra['username'] do
    first_name extra['first_name']
    last_name  extra['last_name']
    email      extra['email']
    password(lazy { extra['password'] || vault_fetch(vault_path['path'], vault_path['field']) })
    key_path extra['key_path']
    org      bootstrap['org']['short_name']
  end
end
