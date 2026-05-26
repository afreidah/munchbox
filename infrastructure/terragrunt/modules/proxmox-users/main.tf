# -----------------------------------------------------------------------------
# PROXMOX-USERS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages Proxmox VE users, roles, and ACLs using the bpg/proxmox provider.
# Passwords are retrieved from Vault to avoid storing in Terraform state.
#
# Components:
#   - Roles: Custom roles with specific privilege sets
#   - Users: PVE realm users for service accounts
#   - ACLs: Permission assignments at specified paths
#
# Security Model:
#   - Passwords stored in Vault, fetched at apply time
#   - Service accounts use minimal required privileges
#   - ACLs use principle of least privilege
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# VAULT SECRETS - Fetch passwords
# -------------------------------------------------------------------------

data "vault_kv_secret_v2" "user_password" {
  for_each = { for k, v in var.users : k => v if v.vault_path != null }

  mount = var.vault_mount
  name  = each.value.vault_path
}

# -------------------------------------------------------------------------
# ROLES
# -------------------------------------------------------------------------

resource "proxmox_virtual_environment_role" "role" {
  for_each = var.roles

  role_id    = each.key
  privileges = each.value.privileges
}

# -------------------------------------------------------------------------
# USERS
# -------------------------------------------------------------------------

resource "proxmox_virtual_environment_user" "user" {
  for_each = var.users

  user_id = each.value.user_id
  password = (
    each.value.vault_path != null
    ? data.vault_kv_secret_v2.user_password[each.key].data[each.value.vault_password_key]
    : each.value.password
  )
  comment = coalesce(each.value.comment, "Managed by Terraform")
  enabled = coalesce(each.value.enabled, true)

  dynamic "acl" {
    for_each = coalesce(each.value.acls, [])
    content {
      path      = acl.value.path
      role_id   = acl.value.role_id
      propagate = coalesce(acl.value.propagate, true)
    }
  }

  # Password changes require user ticket auth, not API token
  # Ignore password changes after initial creation
  lifecycle {
    ignore_changes = [password]
  }

  depends_on = [proxmox_virtual_environment_role.role]
}
