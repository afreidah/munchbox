# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE
# -----------------------------------------------------------------------------
#
# Generic primitive: deploy Worker scripts and bind each to a set of routes.
# The caller supplies the scripts and their pattern => zone_id maps, so this
# works for any edge task (static responders like security.txt/robots.txt,
# redirects, maintenance pages, signing proxies).
#
# var.workers is sensitive, because a worker's bindings can carry credentials.
# Instance keys cannot be, so every for_each here derives its keys through
# nonsensitive() -- script names and route patterns are not the secret part --
# and reads the values back out of var.workers.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  names = nonsensitive(toset(keys(var.workers)))

  fetched = nonsensitive(toset([
    for name, w in var.workers : name if w.content_s3 != null
  ]))

  # Route patterns are unique per zone but not across workers, so the key is
  # both. Flattened because for_each takes one level.
  route_keys = nonsensitive(merge([
    for name, w in var.workers : {
      for pattern in keys(w.routes) :
      "${name}|${pattern}" => { script = name, pattern = pattern }
    }
  ]...))

  # One read per distinct path, however many bindings draw from it.
  vault_paths = nonsensitive(toset(flatten([
    for w in values(var.workers) : [for sb in w.secret_bindings : sb.vault_path]
  ])))
}

# -----------------------------------------------------------------------------
# SECRET BINDINGS
# -----------------------------------------------------------------------------
# Resolved here rather than passed in, so a credential never travels through a
# terragrunt input. It still lands in state, which is the real boundary.

data "vault_kv_secret_v2" "bindings" {
  for_each = local.vault_paths

  mount = var.vault_mount
  name  = each.key
}

locals {
  bindings = {
    for name, w in var.workers :
    name => concat(
      w.bindings,
      [for sb in w.secret_bindings : {
        name = sb.name
        type = "secret_text"
        text = data.vault_kv_secret_v2.bindings[sb.vault_path].data[sb.vault_field]
      }]
    )
  }
}

# -----------------------------------------------------------------------------
# SCRIPT SOURCE
# -----------------------------------------------------------------------------
# Only the workers that name an object are fetched; the rest carry their script
# inline and never touch the S3 provider.

data "aws_s3_object" "content" {
  for_each = local.fetched

  bucket = var.workers[each.key].content_s3.bucket
  key    = var.workers[each.key].content_s3.key
}

# -----------------------------------------------------------------------------
# WORKER SCRIPTS
# -----------------------------------------------------------------------------

resource "cloudflare_workers_script" "this" {
  for_each = local.names

  account_id  = var.account_id
  script_name = each.key
  content = (
    var.workers[each.key].content != null
    ? var.workers[each.key].content
    : data.aws_s3_object.content[each.key].body
  )
  main_module        = var.workers[each.key].main_module
  compatibility_date = var.workers[each.key].compatibility_date
  bindings           = local.bindings[each.key]

  lifecycle {
    precondition {
      condition = (
        (var.workers[each.key].content == null) != (var.workers[each.key].content_s3 == null)
      )
      error_message = "Worker ${each.key}: set exactly one of content or content_s3."
    }
  }
}

# -----------------------------------------------------------------------------
# ROUTES
# -----------------------------------------------------------------------------

resource "cloudflare_workers_route" "this" {
  for_each = local.route_keys

  zone_id = var.workers[each.value.script].routes[each.value.pattern]
  pattern = each.value.pattern
  script  = cloudflare_workers_script.this[each.value.script].script_name
}
