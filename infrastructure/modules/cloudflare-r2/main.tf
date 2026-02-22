# -----------------------------------------------------------------------------
# CLOUDFLARE R2 MODULE
# -----------------------------------------------------------------------------
#
# Creates a Cloudflare R2 object storage bucket.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "cloudflare_r2_bucket" "bucket" {
  account_id = var.account_id
  name       = var.bucket_name
  location   = "WNAM"
}
