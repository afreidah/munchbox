# -----------------------------------------------------------------------------
# REMOTE-FILES MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Single env_helper for every leaf that consumes the remote-files module.
# Branches inside based on the leaf's directory layout:
#
#   provider_type == "pihole-consul" → per-host JSON registration leaf
#     (basename(leaf) = "green"/"logan"); render shared templates from
#     pihole-consul/_templates/ with that host's IP, ship to one target.
#
#   otherwise → static-file leaf (e.g. pihole-shared)
#     look up bundles in root.hcl's remote_files_configs[node_name], load
#     file bytes from <leaf>/files/<file_key>.
#
# Adding a new shape == add a switch arm here; never spawn a sibling helper.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//remote-files"
}

locals {
  root          = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  node_name     = local.root.locals.node_name
  provider_type = local.root.locals.provider_type
  leaf_dir      = get_terragrunt_dir()

  # --- pihole-consul: per-host JSONs via templatefile() ---
  is_pihole_consul = local.provider_type == "pihole-consul"
  pc_node          = local.is_pihole_consul ? one([for n in local.root.locals.pihole_nodes : n if n.name == local.node_name]) : null
  pc_tmpl_dir      = "${get_repo_root()}/infrastructure/terragrunt/global/pihole-consul/_templates"
  pc_tmpl_vars     = local.is_pihole_consul ? { host = local.pc_node.name, ip = local.pc_node.host } : {}
  pc_files = local.is_pihole_consul ? {
    "node-exporter.json" = { destination = "/etc/consul-register/node-exporter.json", content = templatefile("${local.pc_tmpl_dir}/node-exporter.json.tmpl", local.pc_tmpl_vars) }
    "pihole-lb.json"     = { destination = "/etc/consul-register/pihole-lb.json", content = templatefile("${local.pc_tmpl_dir}/pihole-lb.json.tmpl", local.pc_tmpl_vars) }
    "pihole-webui.json"  = { destination = "/etc/consul-register/pihole-webui.json", content = templatefile("${local.pc_tmpl_dir}/pihole-webui.json.tmpl", local.pc_tmpl_vars) }
  } : {}

  pihole_consul_inputs = local.is_pihole_consul ? {
    targets = [local.pc_node]
    bundles = {
      consul_register = {
        files = {
          for fk, f in local.pc_files :
          fk => { content = f.content, destination = f.destination, mode = "0644" }
        }
        check_command   = ""
        restart_command = "systemctl start consul-register.service"
      }
    }
  } : null

  # --- static-file leaves: lookup is try()'d so a leaf removed from root.hcl
  #     (mid-destroy) still inits with empty inputs and can clean up state. ---
  cfg = local.is_pihole_consul ? null : try(local.root.locals.remote_files_configs[local.node_name], null)
  static_inputs = (local.is_pihole_consul || local.cfg == null) ? { targets = [], bundles = {} } : {
    targets = local.cfg.targets
    bundles = {
      for bk, b in local.cfg.bundles :
      bk => {
        files = {
          for fk, f in b.files :
          fk => {
            content     = file("${local.leaf_dir}/files/${fk}")
            destination = f.destination
            mode        = lookup(f, "mode", "0644")
          }
        }
        check_command   = lookup(b, "check_command", "")
        restart_command = b.restart_command
      }
    }
  }

  effective_inputs = local.is_pihole_consul ? local.pihole_consul_inputs : local.static_inputs
}

inputs = local.effective_inputs
