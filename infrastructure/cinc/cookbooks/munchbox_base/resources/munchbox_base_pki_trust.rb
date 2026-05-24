# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_pki_trust
#
# Installs Munchbox internal-PKI CA certificates into the system trust
# store. Each cert is shipped as a cookbook_file under
# `files/default/<name>.crt`; this resource drops them under
# /usr/local/share/ca-certificates/ and runs `update-ca-certificates`
# only when a file actually changes (notify-driven, idempotent).
#
# This is what unblocks chef-internal-Vault calls before vault-agent is
# up: chef's embedded openssl will pick up the new CAs as soon as the
# bundle is rebuilt, with no further per-cookbook plumbing.
#
# Properties:
#   certs - Array of cookbook_file basenames to install (.crt extension
#           preserved as-is). Defaults to the standard Munchbox root +
#           intermediate.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_pki_trust

property :certs, Array, default: %w(munchbox-root-ca.crt munchbox-intermediate-ca.crt)

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Drop each cert, notify a single update-ca-certificates run on change
# -------------------------------------------------------------------------------

action :install do
  # --- :nothing -- only runs when at least one cookbook_file below notifies it ---
  execute 'update-ca-certificates' do
    command 'update-ca-certificates'
    action :nothing
  end

  new_resource.certs.each do |basename|
    cookbook_file "/usr/local/share/ca-certificates/#{basename}" do
      source basename
      cookbook 'munchbox_base'
      owner    'root'
      group    'root'
      mode     '0644'
      notifies :run, 'execute[update-ca-certificates]', :delayed
    end
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Reverse: remove the cookbook-shipped certs + rebuild the bundle
# -------------------------------------------------------------------------------

action :remove do
  execute 'update-ca-certificates' do
    command 'update-ca-certificates'
    action :nothing
  end

  new_resource.certs.each do |basename|
    file "/usr/local/share/ca-certificates/#{basename}" do
      action :delete
      notifies :run, 'execute[update-ca-certificates]', :delayed
    end
  end
end
