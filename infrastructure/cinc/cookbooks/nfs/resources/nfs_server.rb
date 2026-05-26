# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nfs
# Resource:: nfs_server
#
# Installs nfs-kernel-server, renders /etc/exports from a list of hashes,
# runs `exportfs -ra` on change. Service enabled + started. Empty exports
# = no-op (recipe wraps so this resource isn't invoked from per-node
# defaults that haven't opted in).
#
# Each export hash:
#   path     - required
#   clients  - required, e.g. "192.168.68.0/22"
#   options  - required, e.g. "rw,sync,no_subtree_check,no_root_squash"
# -------------------------------------------------------------------------------

unified_mode true

provides :nfs_server

property :package,      String, default: 'nfs-kernel-server'
property :service_name, String, default: 'nfs-server'
property :exports_path, String, default: '/etc/exports'
property :exports,      Array,  default: []

default_action :configure

action :configure do
  return if new_resource.exports.empty?

  # --- ensure the apt package list is fresh so chef's apt_package doesn't pin a
  #     stale version (greenfield / kitchen guests don't otherwise apt-update).
  apt_update 'nfs-server' do
    action :periodic
    frequency 86_400
  end

  apt_package new_resource.package

  # --- exportfs -ra refuses any line whose path doesn't exist on disk; ensure
  #     each exported directory is materialized before /etc/exports references it.
  new_resource.exports.each do |e|
    directory e['path'] do
      owner 'root'
      group 'root'
      mode  '0755'
      recursive true
    end
  end

  # --- Render /etc/exports as a managed block; preserve any user-added comments outside the block. Simplest path: full file overwrite (the comments at the head of the default /etc/exports are vendor docs we don't need to keep). ---
  file new_resource.exports_path do
    owner   'root'
    group   'root'
    mode    '0644'
    content lazy {
      header = "# /etc/exports -- managed by chef (nfs::server). DO NOT EDIT BY HAND.\n\n"
      lines  = new_resource.exports.map { |e| "#{e['path']} #{e['clients']}(#{e['options']})" }
      header + lines.join("\n") + "\n"
    }
    notifies :run, 'execute[exportfs -ra]', :delayed
  end

  service new_resource.service_name do
    action [:enable, :start]
  end

  execute 'exportfs -ra' do
    command 'exportfs -ra'
    action  :nothing
  end
end
