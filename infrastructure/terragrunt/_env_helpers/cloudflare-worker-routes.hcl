# -----------------------------------------------------------------------------
# CLOUDFLARE WORKER-ROUTES ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the generic cloudflare-worker-routes module. Path-keyed on the
# leaf dir name: each consuming leaf gets a branch in local.configs that defines
# its script + routes. The module stays generic (any Worker + routes); all
# usage logic lives here.
#
#   security-txt -> Worker serving an RFC 9116 security.txt at
#   /.well-known/security.txt on both zones. Bump Expires before it lapses.
#
# Provider auth is the scoped "workers" token from the cloudflare-tokens leaf via
# dependency; apply that leaf first.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cloudflare-worker-routes"
}

dependency "cloudflare_tokens" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/cloudflare-tokens"

  mock_outputs = {
    token_values = { workers = "mock-workers-token" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# --- Supplies the artifact bucket credentials a worker fetches its script
#     with. Only the edge-proxy leaf reads this. ---
dependency "access_keys" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/access-keys"

  mock_outputs = {
    vault_data = {
      "s3-bucket/artifacts" = { access_key = "MOCKARTIFACTSACCESSKEY", secret_key = "mock-artifacts-secret-key" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  leaf = basename(get_terragrunt_dir())

  az = local.root.locals.cloudflare_alexfreidah_zone_id
  mz = local.root.locals.cloudflare_munchbox_zone_id

  # --- edge-proxy: one worker per Bandwidth Alliance backend. Those providers
  #     waive egress on traffic leaving to Cloudflare, so a read served through
  #     the edge costs nothing to pull out of the backend.
  #
  #     The worker verifies an inbound signature made with the edge-proxy
  #     keypair, then re-signs to the origin with the backend's own credentials.
  #     Keeping the two separate means the credential s3-orchestrator holds is
  #     not the one that can reach the bucket directly.
  #
  #     ORIGIN_HOST is a bare hostname: the worker sets it on the URL, so a
  #     scheme here would produce an unroutable origin. ---
  edge_backends = {
    b2  = { host = "s3.us-east-005.backblazeb2.com", region = "us-east-005" }
    ibm = { host = "s3.us-east.cloud-object-storage.appdomain.cloud", region = "us-east" }
    oci = { host = "axlubepkixee.compat.objectstorage.us-phoenix-1.oraclecloud.com", region = "us-phoenix-1" }
  }

  # --- The bundle is built in s3-orchestrator and published to the artifacts
  #     bucket under a versioned key. Pinned, never "latest", so republishing
  #     cannot change what is deployed during an unrelated apply. ---
  edge_worker_version = "v0.139.1"

  # --- Everything but the credentials, which can only be read from inputs. ---
  edge_artifact = {
    bucket   = "artifacts"
    key      = "s3-orchestrator/cloudflare-worker/${local.edge_worker_version}/worker.js"
    endpoint = "http://s3-orchestrator.service.consul:9000"
  }

  edge_workers = {
    for name, b in local.edge_backends :
    "s3-orchestrator-${name}-proxy" => {
      bindings = [
        { name = "ORIGIN_HOST", type = "plain_text", text = b.host },
        { name = "ORIGIN_REGION", type = "plain_text", text = b.region },
        { name = "MAX_CLOCK_SKEW_SECONDS", type = "plain_text", text = "300" },
      ]

      secret_bindings = [
        { name = "ORIGIN_ACCESS_KEY_ID", vault_path = "s3-orchestrator", vault_field = "${name}_s3_access_key" },
        { name = "ORIGIN_SECRET_ACCESS_KEY", vault_path = "s3-orchestrator", vault_field = "${name}_s3_secret_key" },
        { name = "PROXY_ACCESS_KEY_ID", vault_path = "edge-proxy/${name}", vault_field = "access_key" },
        { name = "PROXY_SECRET_ACCESS_KEY", vault_path = "edge-proxy/${name}", vault_field = "secret_key" },
      ]

      routes = { "${name}-proxy.munchbox.cc/*" = local.mz }
    }
  }

  # --- security-txt: RFC 9116 body + the minimal ES-module Worker that serves it ---
  security_txt_body = <<-EOT
    Contact: mailto:alex.freidah@gmail.com
    Expires: 2027-06-30T00:00:00Z
    Preferred-Languages: en
  EOT

  # --- per-leaf worker definitions, keyed by leaf dir name. Each branch is a
  #     map of script name => worker, so a leaf can deploy more than one. ---
  configs = {
    "security-txt" = {
      "security-txt" = {
        content = "export default { async fetch() { return new Response(${jsonencode(local.security_txt_body)}, { headers: { \"content-type\": \"text/plain; charset=utf-8\" } }); } };"
        routes = {
          # --- munchbox.cc omitted: apex isn't publicly proxied (no apex site),
          #     so the edge Worker can't serve it; that finding is dismissed. ---
          "alexfreidah.com/.well-known/security.txt" = local.az
        }
      }
    }

  }

  # --- Selected by leaf without a conditional: HCL requires both arms of a
  #     ternary to carry identical object types, and these two shapes differ
  #     (one fetches its script, the other carries it inline). A for with an
  #     if yields an empty map instead, and merge is happy to combine them. ---
  edge_selected  = { for k, v in local.edge_workers : k => v if local.leaf == "edge-proxy" }
  other_selected = { for k, v in lookup(local.configs, local.leaf, {}) : k => v if local.leaf != "edge-proxy" }
}

inputs = {
  cloudflare_api_token = dependency.cloudflare_tokens.outputs.token_values["workers"]
  account_id           = local.root.locals.cloudflare_account_id

  # --- edge-proxy's workers fetch their script, so they need the artifact
  #     bucket credentials, and a dependency output can only be read here. ---
  workers = merge(
    local.other_selected,
    {
      for name, w in local.edge_selected :
      name => merge(w, {
        content_s3 = merge(local.edge_artifact, {
          access_key = dependency.access_keys.outputs.vault_data["s3-bucket/artifacts"].access_key
          secret_key = dependency.access_keys.outputs.vault_data["s3-bucket/artifacts"].secret_key
        })
      })
    },
  )
}
