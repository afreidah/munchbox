# -----------------------------------------------------------------------------
# REMOTE-FILES MODULE
# -----------------------------------------------------------------------------
#
# Ships one or more "bundles" of files to a set of SSH-reachable hosts and
# runs an optional check + restart command per bundle. Built for the Pi-hole
# nodes (armv6l Pi 1s) where running a chef/cinc agent is impractical, but
# generic enough for any "scp + restart" lifecycle.
#
# Components Created:
#   - null_resource.file    one per (target * bundle * file); SFTPs the file
#   - null_resource.restart one per (target * bundle); runs check then restart
#                           after every file in the bundle is in place
#
# Architecture:
#   - Trigger key is the bundle's sha (over file content + destination + mode)
#     so any change in any file of a bundle re-uploads all of them and re-runs
#     the bundle's check + restart.
#   - Restart resource depends_on all file resources to guarantee ordering.
#   - SSH auth uses the local ssh-agent (var.ssh_user assumed to have a valid
#     user cert loaded); no key material is read by terraform itself.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  # --- Stable sha per bundle: any change to any file in the bundle bumps this,
  #     which propagates into every file + restart instance's trigger map. ---
  bundle_shas = {
    for bk, b in var.bundles :
    bk => sha256(jsonencode({
      for fk, f in b.files :
      fk => { content = f.content, destination = f.destination, mode = f.mode }
    }))
  }

  # --- Flattened (target x bundle x file) for the file fan-out. ---
  file_instances = merge([
    for t in var.targets : merge([
      for bk, b in var.bundles : {
        for fk, f in b.files :
        "${t.name}/${bk}/${fk}" => {
          target_name = t.name
          host        = t.host
          bundle_key  = bk
          bundle_sha  = local.bundle_shas[bk]
          content     = f.content
          destination = f.destination
          mode        = f.mode
        }
      }
    ]...)
  ]...)

  # --- Flattened (target x bundle) for the restart fan-out. ---
  bundle_instances = merge([
    for t in var.targets : {
      for bk, b in var.bundles :
      "${t.name}/${bk}" => {
        target_name     = t.name
        host            = t.host
        bundle_key      = bk
        bundle_sha      = local.bundle_shas[bk]
        check_command   = b.check_command
        restart_command = b.restart_command
      }
    }
  ]...)
}

# -----------------------------------------------------------------------------
# FILE DELIVERY: scp every (target x bundle x file)
# -----------------------------------------------------------------------------

resource "null_resource" "file" {
  for_each = local.file_instances

  triggers = {
    host        = each.value.host
    destination = each.value.destination
    mode        = each.value.mode
    bundle_sha  = each.value.bundle_sha
  }

  connection {
    type  = "ssh"
    host  = each.value.host
    user  = var.ssh_user
    agent = true
  }

  # --- Ensure parent dir exists before SFTP (file provisioner won't create). ---
  provisioner "remote-exec" {
    inline = [
      "mkdir -p \"$(dirname '${each.value.destination}')\"",
    ]
  }

  provisioner "file" {
    content     = each.value.content
    destination = each.value.destination
  }

  # --- Set mode after upload; file provisioner doesn't honour mode. ---
  provisioner "remote-exec" {
    inline = [
      "chmod ${each.value.mode} '${each.value.destination}'",
    ]
  }
}

# -----------------------------------------------------------------------------
# CHECK + RESTART per (target x bundle), gated on all file uploads finishing
# -----------------------------------------------------------------------------

resource "null_resource" "restart" {
  for_each = local.bundle_instances

  triggers = {
    host            = each.value.host
    bundle_key      = each.value.bundle_key
    bundle_sha      = each.value.bundle_sha
    check_command   = each.value.check_command
    restart_command = each.value.restart_command
  }

  depends_on = [null_resource.file]

  connection {
    type  = "ssh"
    host  = each.value.host
    user  = var.ssh_user
    agent = true
  }

  # --- join with && so failed check aborts restart (separate inline = no set -e) ---
  provisioner "remote-exec" {
    inline = [
      join(" && ", compact([
        each.value.check_command,
        each.value.restart_command,
      ])),
    ]
  }
}
