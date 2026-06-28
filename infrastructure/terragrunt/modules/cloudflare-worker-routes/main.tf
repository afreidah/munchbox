# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE
# -----------------------------------------------------------------------------
#
# Generic primitive: deploy one Worker script and bind it to a set of routes.
# The caller supplies the script source and the pattern => zone_id map, so this
# works for any edge task (static responders like security.txt/robots.txt,
# redirects, maintenance pages, etc.). One script, many routes.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# WORKER SCRIPT
# -----------------------------------------------------------------------------

resource "cloudflare_workers_script" "this" {
  account_id         = var.account_id
  script_name        = var.script_name
  content            = var.content
  main_module        = var.main_module
  compatibility_date = var.compatibility_date
}

# -----------------------------------------------------------------------------
# ROUTES
# -----------------------------------------------------------------------------
# One route per pattern => zone_id entry, all bound to the script above.

resource "cloudflare_workers_route" "this" {
  for_each = var.routes

  zone_id = each.value
  pattern = each.key
  script  = cloudflare_workers_script.this.script_name
}
