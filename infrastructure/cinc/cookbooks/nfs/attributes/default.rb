# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nfs / Attributes: default
#
# `mounts` is an array of hashes; each hash drives a `nfs_mount` call.
# Keys: mount_point (required), device (required), fstype (optional),
# options (optional). Roles/per-node attributes append to this list to
# pull in their mounts.
# -------------------------------------------------------------------------------

cookbook = 'nfs'

default[cookbook]['client'] = {
  package: 'nfs-common',
  # --- Shared mounts every node in a role gets (e.g. gdrive on proxmox_vm). ---
  mounts: [],
  # --- Per-node additions appended at converge time so a single node can add a mount without redefining the shared list (chef merges hashes deep but replaces arrays). ---
  extra_mounts: [],
}

# --- Server side. exports = list of hashes {path:, clients:, options:}; empty = recipe is a no-op. mccoy + rubirosa are the only consumers today. ---
default[cookbook]['server'] = {
  package:      'nfs-kernel-server',
  service_name: 'nfs-server',
  exports_path: '/etc/exports',
  exports:      [],
}
