# -----------------------------------------------------------------------------
# RAMBLE MODULE
# -----------------------------------------------------------------------------
#
# Publishes packs and jobs to the Ramble registry under one namespace. Each
# var.resources entry becomes a ramble_resource keyed by its Ramble name, so an
# entry that already exists is taken over by importing namespace/name.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# PACKS AND JOBS - one per var.resources entry
# -------------------------------------------------------------------------

resource "ramble_resource" "this" {
  for_each = var.resources

  namespace      = var.namespace
  name           = each.key
  type           = each.value.type
  repository_url = each.value.repository_url
  file_path      = each.value.file_path
  description    = each.value.description
  license        = each.value.license
  tags           = each.value.tags
  version        = each.value.version
}
