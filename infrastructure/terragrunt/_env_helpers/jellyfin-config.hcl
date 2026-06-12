# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the jellyfin-config module. The provider endpoint + api_key
# come from Vault (secret/jellyfin) via TF_VAR_* exported by munchbox-env.sh;
# the singleton configs and scheduled tasks come from root.hcl. Configs default
# to null (unmanaged) so a fresh apply is a no-op until real values are codified.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//jellyfin-config"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  # --- take the URL token only; the Vault value may carry a trailing note ---
  jellyfin_endpoint = trimspace(split(" ", get_env("TF_VAR_jellyfin_endpoint", ""))[0])
  jellyfin_api_key  = get_env("TF_VAR_jellyfin_api_key", "")

  # --- json-encode each settings object here; null passes through untouched ---
  encoding_configuration_json = local.root.locals.jellyfin_encoding_configuration == null ? null : jsonencode(local.root.locals.jellyfin_encoding_configuration)
  livetv_configuration_json   = local.root.locals.jellyfin_livetv_configuration == null ? null : jsonencode(local.root.locals.jellyfin_livetv_configuration)
  system_configuration_json   = local.root.locals.jellyfin_system_configuration == null ? null : jsonencode(local.root.locals.jellyfin_system_configuration)

  scheduled_tasks = {
    for k, t in local.root.locals.jellyfin_scheduled_tasks :
    k => { task_id = t.task_id, triggers_json = jsonencode(t.triggers) }
  }
}
