# -----------------------------------------------------------------------------
# CLOUDFLARE-WEB-ANALYTICS MODULE
# -----------------------------------------------------------------------------
#
# Enables Cloudflare Web Analytics (RUM) per zone. Each cloudflare_web_analytics_site
# is created at the account level and, for orange-clouded zones, auto-injects the
# browser beacon (auto_install) so no site code change is needed; once enabled the
# rum* GraphQL datasets populate for that zone. The resource needs Account Settings
# Read + Write, which is why this is its own module/token rather than an extension
# of cloudflare-zone-settings (whose token is zone-scoped). Enabling is not
# retroactive - RUM collection starts going forward.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "cloudflare_web_analytics_site" "this" {
  for_each = var.sites

  account_id   = var.account_id
  zone_tag     = each.value.zone_tag
  auto_install = each.value.auto_install
  enabled      = each.value.enabled
  host         = each.value.host
  lite         = each.value.lite

  lifecycle {
    # The API does not return `enabled` on read (only ruleset.enabled is read
    # back), so it reads as null and otherwise diffs on every plan. Set it on
    # create, then ignore the phantom drift.
    ignore_changes = [enabled]
  }
}
