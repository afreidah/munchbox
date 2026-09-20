# -----------------------------------------------------------------------------
# VAULT SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Single home for writing generated secrets to Vault. The secret structure is
# declared in the vault_secrets map below; each entry names a generator leaf
# (source), a key into that generator's vault_data, and optional static
# non-secret values to merge. Adding a secret is a map entry (+ one dependency
# block here if it introduces a new generator).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//vault-kv-secrets"
}

dependency "cloudflare_tokens" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/cloudflare-tokens"

  mock_outputs = {
    vault_data = {
      wandns       = { api_token = "mock-wandns-token" }
      logcollector = { api_token = "mock-logcollector-token" }
      dnsedge      = { api_token = "mock-dnsedge-token" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "aptly_secrets" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/aptly"

  mock_outputs = {
    vault_data = { admin = { password = "mock-aptly-password", htpasswd = "admin:mock-bcrypt-hash" } }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "gossip_keys" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/gossip-keys"

  mock_outputs = {
    vault_data = { nomad = { key = "bW9jay1nb3NzaXAta2V5LTMyLWJ5dGVzLXBhZGRpbmc=" } }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "passwords" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/passwords"

  mock_outputs = {
    vault_data = {
      "proxmox/api-token"           = { id = "mock-token-id", secret = "mock-token-secret" }
      "vaultwarden/master-password" = { password = "mock-master-password" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "cinc_server_keys" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/cinc-server-keys"

  mock_outputs = {
    vault_data = {
      "forgejo-ci" = {
        password    = "mock-cinc-ci-password"
        private_key = "-----BEGIN RSA PRIVATE KEY-----\nmock\n-----END RSA PRIVATE KEY-----\n"
        public_key  = "-----BEGIN PUBLIC KEY-----\nmock\n-----END PUBLIC KEY-----\n"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "access_keys" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/cluster/secrets/access-keys"

  mock_outputs = {
    vault_data = {
      "edge-proxy/b2"  = { access_key = "MOCKEDGEPROXYB2KEY", secret_key = "mock-edge-proxy-b2-secret" }
      "edge-proxy/ibm" = { access_key = "MOCKEDGEPROXYIBMKEY", secret_key = "mock-edge-proxy-ibm-secret" }
      "edge-proxy/oci" = { access_key = "MOCKEDGEPROXYOCIKEY", secret_key = "mock-edge-proxy-oci-secret" }
      "dnsdist"        = { access_key = "MOCKDNSDISTACCESSKEY", secret_key = "mock-dnsdist-secret-key" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "code_engine" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/ibm/code-engine"

  mock_outputs = {
    vault_data = {
      vagabond = {
        api_key    = "mock-code-engine-api-key"
        project_id = "00000000-0000-0000-0000-000000000000"
        region     = "us-south"
        endpoint   = "https://api.us-south.codeengine.cloud.ibm.com/v2"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- source = generator leaf; key = index into its vault_data; static =
  #     non-secret values merged in (keyed to match the Vault data keys). ---
  vault_secrets = {
    "aptly-admin" = {
      source = "aptly_secrets"
      key    = "admin"
    }
    "cloudflare-wandns" = {
      source = "cloudflare_tokens"
      key    = "wandns"
      static = { zone_id = local.root.locals.cloudflare_munchbox_zone_id }
    }
    "cloudflare-logcollector" = {
      source = "cloudflare_tokens"
      key    = "logcollector"
    }
    "nomad/gossip-key" = {
      source = "gossip_keys"
      key    = "nomad"
    }
    # --- the cinc_server cookbook reads password + public_key to create the
    #     user; Forgejo CI reads private_key to authenticate as it. ---
    "cinc-server/ci/forgejo" = {
      source = "cinc_server_keys"
      key    = "forgejo-ci"
    }
    # --- the credentials terraform authenticates to Proxmox and Vaultwarden
    #     with; their own paths, since the parent secrets hold other fields. ---
    "proxmox/api-token" = {
      source = "passwords"
      key    = "proxmox/api-token"
    }
    "vaultwarden/master-password" = {
      source = "passwords"
      key    = "vaultwarden/master-password"
    }
    "cloudflare-dnsedge" = {
      source = "cloudflare_tokens"
      key    = "dnsedge"
    }
    "edge-proxy/b2" = {
      source = "access_keys"
      key    = "edge-proxy/b2"
    }
    "edge-proxy/ibm" = {
      source = "access_keys"
      key    = "edge-proxy/ibm"
    }
    "edge-proxy/oci" = {
      source = "access_keys"
      key    = "edge-proxy/oci"
    }
    "dnsdist" = {
      source = "access_keys"
      key    = "dnsdist"
    }
    # --- the api_key is the only secret here; project_id, region and endpoint
    #     travel with it because a key without its coordinates reaches nothing,
    #     and vagabond's provider block names one path rather than four. ---
    "vagabond/code-engine" = {
      source = "code_engine"
      key    = "vagabond"
    }
  }
}

# --- dependency outputs can only be referenced from inputs, not locals; map
#     source name -> generator vault_data and index by key, merging statics ---
inputs = {
  secrets = {
    for name, s in local.vault_secrets :
    name => {
      data = merge(
        try(s.static, {}),
        {
          aptly_secrets     = dependency.aptly_secrets.outputs.vault_data
          cloudflare_tokens = dependency.cloudflare_tokens.outputs.vault_data
          access_keys       = dependency.access_keys.outputs.vault_data
          gossip_keys       = dependency.gossip_keys.outputs.vault_data
          cinc_server_keys  = dependency.cinc_server_keys.outputs.vault_data
          passwords         = dependency.passwords.outputs.vault_data
          code_engine       = dependency.code_engine.outputs.vault_data
        }[s.source][s.key],
      )
    }
  }
}
