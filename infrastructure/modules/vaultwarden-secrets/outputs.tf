# -----------------------------------------------------------------------------
# VAULTWARDEN-SECRETS MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# FOLDERS
# -----------------------------------------------------------------------------

output "folder_ids" {
  description = "Map of folder keys to folder IDs"
  value = {
    for key, folder in bitwarden_folder.folders : key => folder.id
  }
}

# -----------------------------------------------------------------------------
# LOGIN ITEMS
# -----------------------------------------------------------------------------

output "login_item_ids" {
  description = "Map of login item keys to item IDs"
  value = {
    for key, login in bitwarden_item_login.logins : key => login.id
  }
}
