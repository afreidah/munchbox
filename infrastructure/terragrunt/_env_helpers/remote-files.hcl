# -----------------------------------------------------------------------------
# REMOTE-FILES MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Single env_helper for every leaf that consumes the remote-files module.
# Branches inside based on the leaf's directory layout:
#
#   provider_type == "pihole-consul" → per-host JSON registration leaf
#     (basename(leaf) = "green"/"logan"); render the shared
#     pihole-consul/_templates/ with that host's IP, ship the JSONs to
#     /etc/consul-register/, ship the probe-and-POST consul-register.sh
#     to /usr/local/bin/, then restart consul-register.service so it
#     re-runs against the freshest defs (was #30: script now probes
#     locally each cycle and overrides .Check.Status with real result).
#
#   otherwise → static-file leaf (e.g. dns/pihole/shared)
#     look up bundles in remote_files_configs[node_name] (below), load
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

  # --- SSH-reachable Pi-hole nodes (remote-files targets) ---
  pihole_nodes = [
    { name = "green", host = "192.168.68.62" },
    { name = "logan", host = "192.168.68.64" },
  ]

  # --- keyed by leaf dir name (node_name). Each entry = targets to ship to +
  #     bundles of files with a check/restart hook. File CONTENT is not here;
  #     each leaf owns a files/ dir and bytes load by file_key. ---
  remote_files_configs = {
    shared = {
      targets = local.pihole_nodes
      bundles = {
        unbound = {
          files = {
            "pi-hole.conf" = { destination = "/etc/unbound/unbound.conf.d/pi-hole.conf" }
          }
          # --- mkdir+chown: logfile dir missing pre-existing; checkconf fails without it ---
          check_command   = "mkdir -p /var/log/unbound && chown unbound:unbound /var/log/unbound && unbound-checkconf /etc/unbound/unbound.conf.d/pi-hole.conf"
          restart_command = "systemctl restart unbound && systemctl is-active --quiet unbound"
        }

        dnsmasq = {
          files = {
            "10-munchbox-vips.conf" = { destination = "/etc/dnsmasq.d/10-munchbox-vips.conf" }
            "munchbox-no-ipv6.conf" = { destination = "/etc/dnsmasq.d/munchbox-no-ipv6.conf" }
          }
          # --- reloaddns reloads dnsmasq.d w/o FTL restart (avoids the 30s outage window) ---
          check_command   = "pihole-FTL dnsmasq-test"
          restart_command = "pihole reloaddns"
        }

        ftl = {
          files = {
            "pihole-FTL.conf" = { destination = "/etc/pihole/pihole-FTL.conf" }
          }
          # --- MAXDBDAYS is read at FTL startup, so a full restart is required
          #     (one-time prune of the query DB to the new retention). dnsdist +
          #     the other Pi-hole cover the brief single-host gap. ---
          restart_command = "systemctl restart pihole-FTL && systemctl is-active --quiet pihole-FTL"
        }

        node_exporter = {
          files = {
            "node_exporter.service" = { destination = "/etc/systemd/system/node_exporter.service" }
          }
          restart_command = "systemctl daemon-reload && systemctl enable --now node_exporter && systemctl is-active --quiet node_exporter"
        }

        consul_register = {
          files = {
            "consul-register.sh"      = { destination = "/usr/local/bin/consul-register.sh", mode = "0755" }
            "consul-register.service" = { destination = "/etc/systemd/system/consul-register.service" }
            "consul-register.timer"   = { destination = "/etc/systemd/system/consul-register.timer" }
          }
          # --- daemon-reload, enable timer, kick the one-shot once so JSON deltas land immediately ---
          restart_command = "systemctl daemon-reload && systemctl enable --now consul-register.timer && systemctl start consul-register.service"
        }
      }
    }
  }

  # --- pihole-consul: per-host JSONs + the probe-and-POST script (leaves under dns/pihole/consul/<host>) ---
  is_pihole_consul = strcontains(local.leaf_dir, "/dns/pihole/consul/")
  pc_node          = local.is_pihole_consul ? one([for n in local.pihole_nodes : n if n.name == local.node_name]) : null
  pc_tmpl_dir      = "${get_repo_root()}/infrastructure/terragrunt/dns/pihole/consul/_templates"
  pc_tmpl_vars     = local.is_pihole_consul ? { host = local.pc_node.name, ip = local.pc_node.host } : {}
  pc_files = local.is_pihole_consul ? {
    "node-exporter.json" = { destination = "/etc/consul-register/node-exporter.json", mode = "0644", content = templatefile("${local.pc_tmpl_dir}/node-exporter.json.tmpl", local.pc_tmpl_vars) }
    "pihole-lb.json"     = { destination = "/etc/consul-register/pihole-lb.json", mode = "0644", content = templatefile("${local.pc_tmpl_dir}/pihole-lb.json.tmpl", local.pc_tmpl_vars) }
    "pihole-webui.json"  = { destination = "/etc/consul-register/pihole-webui.json", mode = "0644", content = templatefile("${local.pc_tmpl_dir}/pihole-webui.json.tmpl", local.pc_tmpl_vars) }
    # --- The probe-and-POST script; lives next to the JSONs (was bug #30) ---
    "consul-register.sh" = { destination = "/usr/local/bin/consul-register.sh", mode = "0755", content = file("${local.pc_tmpl_dir}/consul-register.sh") }
  } : {}

  pihole_consul_inputs = local.is_pihole_consul ? {
    targets = [local.pc_node]
    bundles = {
      consul_register = {
        files = {
          for fk, f in local.pc_files :
          fk => { content = f.content, destination = f.destination, mode = f.mode }
        }
        check_command   = ""
        restart_command = "systemctl restart consul-register.service"
      }
    }
  } : null

  # --- static-file leaves: lookup is try()'d so a leaf removed from root.hcl
  #     (mid-destroy) still inits with empty inputs and can clean up state. ---
  cfg = local.is_pihole_consul ? null : try(local.remote_files_configs[local.node_name], null)
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
