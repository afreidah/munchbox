# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# Auth comes from a token with Workers Scripts + Routes write, supplied by the
# caller (e.g. the cloudflare-tokens dependency).
#
# The S3 provider serves the workers whose script is fetched rather than written
# inline. Its credentials come from the first worker that names an object, since
# the artifact store is one place; a leaf with no such worker configures it with
# placeholders it never uses. The endpoint is S3-compatible rather than AWS, so
# path-style addressing is forced and the AWS-only preflight calls are skipped.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  s3_sources = [for w in values(var.workers) : w.content_s3 if w.content_s3 != null]
  s3         = try(local.s3_sources[0], null)
}

provider "aws" {
  access_key = try(local.s3.access_key, "unused")
  secret_key = try(local.s3.secret_key, "unused")
  region     = try(local.s3.region, "us-east-1")

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = try(local.s3.endpoint, "http://localhost:9000")
  }
}
