# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Resource:: cinc_server_user
#
# Idempotently creates a server user via `chef-server-ctl user-create`,
# capturing the generated private key to `key_path`. `user-show` is the
# existence check. When `org` is set, the user is also added to that org
# as an admin so they can manage cookbooks/nodes from `knife`.
#
# Properties:
#   username   - Login name (default: resource name).
#   first_name - Given name (required).
#   last_name  - Family name (required).
#   email      - Email address (required).
#   password   - Initial password (required; user can rotate later).
#   key_path   - Where to write the generated private key (required).
#   org        - Optional org short_name to add the user to as admin.
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_server_user

property :username,   String, name_property: true
property :first_name, String, required: true
property :last_name,  String, required: true
property :email,      String, required: true
property :password,   String, required: true, sensitive: true
property :key_path,   String, required: true
property :org,        String

default_action :create

# -------------------------------------------------------------------------------
# Action :create  --  Create the user (and its key) + optionally add to an org as admin
# -------------------------------------------------------------------------------

action :create do
  # --- Ensure parent dir for the captured pem exists with restrictive perms ---
  directory ::File.dirname(new_resource.key_path) do
    owner 'root'
    group 'root'
    mode  '0700'
    recursive true
  end

  execute "chef-server-ctl user-create #{new_resource.username}" do
    command [
      'chef-server-ctl', 'user-create',
      new_resource.username,
      new_resource.first_name,
      new_resource.last_name,
      new_resource.email,
      new_resource.password,
      '--filename', new_resource.key_path
    ]
    environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
    sensitive true
    not_if "chef-server-ctl user-show '#{new_resource.username}'"
  end

  # --- Lock down the captured key (manages metadata when file exists; does not create) ---
  file new_resource.key_path do
    owner 'root'
    group 'root'
    mode  '0600'
    only_if { ::File.exist?(new_resource.key_path) }
  end

  if new_resource.org
    execute "chef-server-ctl org-user-add #{new_resource.org} #{new_resource.username} --admin" do
      command "chef-server-ctl org-user-add '#{new_resource.org}' '#{new_resource.username}' --admin"
      environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
      # --- cinc-15.10.91 lacks `org-user-list`; word-match org against `user-show --with-orgs` output. ---
      not_if "chef-server-ctl user-show '#{new_resource.username}' --with-orgs | grep -E '^organizations:' | grep -wq '#{new_resource.org}'"
    end
  end
end

# -------------------------------------------------------------------------------
# Action :delete  --  Remove the user (test cleanup; deletes the captured pem too)
# -------------------------------------------------------------------------------

action :delete do
  execute "chef-server-ctl user-delete #{new_resource.username}" do
    command "chef-server-ctl user-delete '#{new_resource.username}' --yes"
    environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
    only_if "chef-server-ctl user-show '#{new_resource.username}'"
  end
end
