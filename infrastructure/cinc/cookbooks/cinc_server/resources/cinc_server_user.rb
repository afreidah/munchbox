# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Resource:: cinc_server_user
#
# Idempotently creates a server user via `chef-server-ctl user-create`, with
# `user-show` as the existence check. When `org` is set, the user is also added
# to that org as an admin so they can manage cookbooks/nodes from `knife`.
#
# The key comes from exactly one of two sources. `public_key` is attached after
# create and the server's own minted key deleted, so no private half is kept on
# this host; `key_path` instead captures the minted private key to that path.
#
# Properties:
#   username        - Login name (default: resource name).
#   first_name      - Given name (required).
#   last_name       - Family name (required).
#   email           - Email address (required).
#   password        - Initial password (required; user can rotate later).
#   public_key      - PEM public key to install as the user's default key.
#   public_key_path - Where to render `public_key` for chef-server-ctl to read.
#   key_path        - Where to write a server-generated private key.
#   org             - Optional org short_name to add the user to as admin.
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_server_user

property :username,        String, name_property: true
property :first_name,      String, required: true
property :last_name,       String, required: true
property :email,           String, required: true
property :password,        String, required: true, sensitive: true
property :public_key,      String
property :public_key_path, String
property :key_path,        String
property :org,             String

default_action :create

# -------------------------------------------------------------------------------
# Action :create  --  Create the user (and its key) + optionally add to an org as admin
# -------------------------------------------------------------------------------

action :create do
  supplied_key = !new_resource.public_key.nil? && !new_resource.public_key_path.nil?
  capture_key  = !new_resource.key_path.nil?

  if supplied_key == capture_key
    raise Chef::Exceptions::ValidationFailed,
          "cinc_server_user[#{new_resource.username}]: set exactly one of " \
          'public_key + public_key_path (both), or key_path'
  end

  key_file = supplied_key ? new_resource.public_key_path : new_resource.key_path

  directory ::File.dirname(key_file) do
    owner 'root'
    group 'root'
    mode  '0700'
    recursive true
  end

  if supplied_key
    # --- public half only; world-readable is fine, the 0700 dir gates it ---
    file new_resource.public_key_path do
      owner   'root'
      group   'root'
      mode    '0644'
      content new_resource.public_key
    end
  end

  # --- user-create always mints its own key: `--user-key` and `--prevent-keygen`
  #     both send `create_key: nil`, which the API rejects. Without `--filename`
  #     the minted private key goes to stdout and is dropped on the floor. ---
  key_args = supplied_key ? [] : ['--filename', new_resource.key_path]

  execute "chef-server-ctl user-create #{new_resource.username}" do
    command [
      'chef-server-ctl', 'user-create',
      new_resource.username,
      new_resource.first_name,
      new_resource.last_name,
      new_resource.email,
      new_resource.password
    ].concat(key_args)
    environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
    sensitive true
    not_if "chef-server-ctl user-show '#{new_resource.username}'"
  end

  if supplied_key
    execute "chef-server-ctl add-user-key #{new_resource.username}" do
      command [
        'chef-server-ctl', 'add-user-key', new_resource.username,
        '-p', new_resource.public_key_path,
        '-k', new_resource.username
      ]
      environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
      not_if "chef-server-ctl list-user-keys '#{new_resource.username}' | grep -q '^name: #{new_resource.username}$'"
    end

    # --- ordered after the attach, so the user is never left without a key ---
    execute "chef-server-ctl delete-user-key #{new_resource.username} default" do
      command ['chef-server-ctl', 'delete-user-key', new_resource.username, 'default']
      environment 'CINC_LICENSE' => 'accept', 'CHEF_LICENSE' => 'accept'
      only_if "chef-server-ctl list-user-keys '#{new_resource.username}' | grep -q '^name: default$'"
    end
  end

  unless supplied_key
    # --- Lock down the captured key (manages metadata when file exists; does not create) ---
    file new_resource.key_path do
      owner 'root'
      group 'root'
      mode  '0600'
      only_if { ::File.exist?(new_resource.key_path) }
    end
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
