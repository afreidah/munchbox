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
  #     (lengths default to S3-style). ---
  access_key_requests = {
    # --- edge-proxy/*: the keypair s3-orchestrator signs with when it reaches a
    #     backend through its Cloudflare worker. The worker verifies this
    #     signature, then re-signs to the origin with the backend's own
    #     credentials, so the two are deliberately separate. ---
    "edge-proxy/b2"  = {}
    "edge-proxy/ibm" = {}
    "edge-proxy/oci" = {}
    # --- dnsdist web console pair: access_key -> apiKey, secret_key -> password ---
    "dnsdist" = {}
  }
}

inputs = {
  credentials = local.access_key_requests
}
