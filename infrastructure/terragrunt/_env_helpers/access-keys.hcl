# -----------------------------------------------------------------------------
# ACCESS-KEYS ENV HELPER
# -----------------------------------------------------------------------------
#
# Generates access-key / secret-key credential pairs from the access_key_requests
# map below. Vault-free: the pairs are exposed as outputs and written to Vault by
# the vault-secrets leaf via terragrunt dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//access-keys"
}

locals {
  # --- key = Vault secret name a consumer reads; value = generation options
  #     (lengths default to S3-style). s3-bucket/* authenticate the
  #     s3-orchestrator virtual buckets of the matching name. ---
  access_key_requests = {
    "s3-bucket/unified" = {}
    "s3-bucket/aptly"   = { id_length = 32, secret_length = 64 }
    # --- dnsdist web console pair: access_key -> apiKey, secret_key -> password ---
    "dnsdist" = {}
  }
}

inputs = {
  credentials = local.access_key_requests
}
