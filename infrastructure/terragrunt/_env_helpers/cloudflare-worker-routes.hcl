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

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  leaf = basename(get_terragrunt_dir())

  az = local.root.locals.cloudflare_alexfreidah_zone_id

  # --- security-txt: RFC 9116 body + the minimal ES-module Worker that serves it ---
  security_txt_body = <<-EOT
    Contact: mailto:alex.freidah@gmail.com
    Expires: 2027-06-30T00:00:00Z
    Preferred-Languages: en
  EOT

  # --- per-leaf worker definitions, keyed by leaf dir name ---
  configs = {
    "security-txt" = {
      script_name = "security-txt"
      content     = "export default { async fetch() { return new Response(${jsonencode(local.security_txt_body)}, { headers: { \"content-type\": \"text/plain; charset=utf-8\" } }); } };"
      routes = {
        # --- munchbox.cc omitted: apex isn't publicly proxied (no apex site), so
        #     the edge Worker can't serve it; that finding is dismissed. ---
        "alexfreidah.com/.well-known/security.txt" = local.az
      }
    }
  }

  cfg = local.configs[local.leaf]
}

inputs = {
  cloudflare_api_token = dependency.cloudflare_tokens.outputs.token_values["workers"]
  account_id           = local.root.locals.cloudflare_account_id
  script_name          = local.cfg.script_name
  content              = local.cfg.content
  routes               = local.cfg.routes
}
