# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Recipe:: data_bag_secret
#
# Enforces presence + perms on /etc/cinc/encrypted_data_bag_secret. The
# file itself is provisioned out-of-band by the workstation bootstrap
# script (infrastructure/scripts/install-data-bag-secret.sh) -- cinc
# can't lay down its own decryption key, since the AppRole creds needed
# to read the secret out of Vault themselves live behind that key.
#
# This recipe is the safety net: any future converge raises loudly if
# the file is missing or has been chmod'd open, instead of silently
# failing the next encrypted data-bag fetch.
# -------------------------------------------------------------------------------

SECRET_PATH = '/etc/cinc/encrypted_data_bag_secret'

directory '/etc/cinc' do
  owner 'root'
  group 'root'
  mode  '0755'
end

# --- Fail-loud guard; convergence stops before any encrypted-data-bag-dependent recipe runs. not_if keeps it idempotent: it fires (and raises) solely when the key is absent. ---
ruby_block 'verify encrypted_data_bag_secret is present' do
  block do
    raise "#{SECRET_PATH} is missing -- run infrastructure/scripts/install-data-bag-secret.sh <node> on the workstation to provision it from Vault"
  end
  not_if { ::File.exist?(SECRET_PATH) }
end

# --- Enforce perms without touching contents (chef's file resource leaves content alone when no `content` is set) ---
file SECRET_PATH do
  owner 'root'
  group 'root'
  mode  '0640'
end
