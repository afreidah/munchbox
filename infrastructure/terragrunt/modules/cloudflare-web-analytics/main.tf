# -----------------------------------------------------------------------------
# CLOUDFLARE-WEB-ANALYTICS MODULE
# -----------------------------------------------------------------------------
#
# Enables Cloudflare Web Analytics (RUM) per zone. Each cloudflare_web_analytics_site
# is created at the account level and mints the site token the browser beacon
# carries; the rum* GraphQL datasets populate for a zone once its beacon reports.
# The resource needs Account Settings Read + Write, which is why this is its own
# module/token rather than an extension of cloudflare-zone-settings (whose token is
# zone-scoped). auto_install asks the edge to inject the beacon and the edge does
# not do it, so each site embeds the snippets output itself; enabling is not
# retroactive and collection starts going forward.
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

    # ruleset.enabled is what the API does read back and what the dashboard
    # reports, so the assertion is made against it. Ignoring `enabled` also
    # blinds the plan to a ruleset switched off outside Terraform, which costs
    # nothing and reports nothing: the site keeps existing, the token keeps
    # minting, the plan stays clean and no page is ever measured. A site
    # addressed by host carries no ruleset and is exempt.
    postcondition {
      condition     = each.value.zone_tag == null || try(self.ruleset.enabled, false)
      error_message = "Web Analytics RUM is off for ${each.key}: the site exists but its ruleset is disabled, so nothing is collected."
    }
  }
}
