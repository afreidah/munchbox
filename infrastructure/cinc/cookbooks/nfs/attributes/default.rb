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
  # --- Shared mounts every node in a role gets (e.g. gdrive on proxmox_node). ---
  mounts: [],
  # --- Per-node additions appended at converge time so a single node can add a mount without redefining the shared list (chef merges hashes deep but replaces arrays). ---
  extra_mounts: [],
}
