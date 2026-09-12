# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare token with Workers Scripts + Routes write."
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "Cloudflare account id that owns the Worker scripts."
  type        = string
}

# Keyed by script name. A caller deploying one worker passes one entry; a caller
# deploying a script per backend passes several; an empty map deploys none,
# which is how a worker is retired without emptying the leaf.
#
# content and content_s3 are alternatives: a script written inline here, or one
# built elsewhere and fetched. Cloudflare runs JavaScript, so anything authored
# in TypeScript is bundled before it gets this far.
variable "workers" {
  description = "Worker scripts to deploy, keyed by script name."
  type = map(object({
    content = optional(string)

    # The object must be stored with a textual content type; the data source
    # exposes no body for anything else.
    content_s3 = optional(object({
      bucket     = string
      key        = string
      endpoint   = string
      access_key = string
      secret_key = string
      region     = optional(string, "us-east-1")
    }))

    main_module        = optional(string, "worker.js")
    compatibility_date = optional(string, "2025-01-01")

    # Values the script reads off its env. Cloudflare stores a secret_text
    # binding write-only, but Terraform keeps it in state, so such a value is
    # only as protected as the state backend.
    bindings = optional(list(object({
      name = string
      type = string
      text = optional(string)
    })), [])

    # Secret bindings resolved from Vault rather than passed in, so a
    # credential never travels through a terragrunt input. Each becomes a
    # secret_text binding alongside the ones above.
    secret_bindings = optional(list(object({
      name        = string
      vault_path  = string
      vault_field = string
    })), [])

    # Route pattern => zone id. One cloudflare_workers_route per entry.
    routes = optional(map(string), {})
  }))
  default   = {}
  sensitive = true
}

variable "vault_mount" {
  description = "KV v2 mount that secret_bindings paths are relative to."
  type        = string
  default     = "secret"
}
