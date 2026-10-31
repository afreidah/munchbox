# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Resource:: cinc_server_vault_publish
#
# Copies files the server generates into one KV v2 secret, one field per
# file. Writes only when the stored copy differs, so a converge never adds a
# KV version for unchanged content.
#
# Properties:
#   path  - KV v2 path to write (secret/data/...) (default: resource name).
#   files - Hash of Vault field name => file path whose content it carries.
# -------------------------------------------------------------------------------

unified_mode true

provides :cinc_server_vault_publish

property :path,  String, name_property: true
property :files, Hash,   required: true

default_action :publish

# -------------------------------------------------------------------------------
# Action :publish  --  Write the files' contents to Vault when they differ from the stored copy
# -------------------------------------------------------------------------------

action :publish do
  data = new_resource.files.transform_values { |file| ::File.read(file) }

  unless vault_kv_read(new_resource.path) == data
    converge_by("publish #{new_resource.files.keys.sort.join(', ')} to #{new_resource.path}") do
      vault_kv_write(new_resource.path, data)
    end
  end
end
