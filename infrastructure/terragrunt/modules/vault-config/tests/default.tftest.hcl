# -----------------------------------------------------------------------------
# vault-config module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's composition: each feature flag toggles its resource
# set, for_each maps fan out the expected keys, the JWT/PKI plumbing wires
# up correctly, and minimal-config edge case produces zero managed resources.
# -----------------------------------------------------------------------------

mock_provider "vault" {
  # --- data.vault_generic_secret.pki_int_ca needs a known .data.certificate at plan time ---
  mock_data "vault_generic_secret" {
    defaults = {
      data = {
        certificate = "-----BEGIN CERTIFICATE-----\nMIIDmocktest\n-----END CERTIFICATE-----"
      }
    }
  }
}

mock_provider "random" {}

variables {
  consul_bootstrap_token = "test-token"
}

# -------------------------------------------------------------------------
# KV mount enabled by default at path "secret"
# -------------------------------------------------------------------------

run "baseline_kv_enabled" {
  command = plan

  # --- kv mount resource is created (count = 1) ---
  assert {
    condition     = length(vault_mount.kv) == 1
    error_message = "KV mount should be created when kv_enabled is true"
  }

  # --- default mount path is "secret" ---
  assert {
    condition     = vault_mount.kv[0].path == "secret"
    error_message = "KV mount path should default to 'secret'"
  }

  # --- kv_path output mirrors the mount path ---
  assert {
    condition     = output.kv_path == "secret"
    error_message = "kv_path output should be 'secret' when KV is enabled"
  }

  # --- ssh signer outputs are null when ssh_ca_enabled is off (default) ---
  assert {
    condition     = output.ssh_host_signer_path == null && output.ssh_client_signer_path == null
    error_message = "ssh signer paths should be null when ssh_ca_enabled is false"
  }

  # --- database_backend_path output is null when database secrets are off ---
  assert {
    condition     = output.database_backend_path == null
    error_message = "database_backend_path should be null by default"
  }
}

# -------------------------------------------------------------------------
# Consul secrets backend enabled by default
# -------------------------------------------------------------------------

run "baseline_consul_secrets_enabled" {
  command = plan

  # --- consul backend resource is created ---
  assert {
    condition     = length(vault_consul_secret_backend.consul) == 1
    error_message = "Consul secrets backend should be created when consul_secrets_enabled is true"
  }

  # --- consul_backend_path output reflects the fixed "consul" path ---
  assert {
    condition     = output.consul_backend_path == "consul"
    error_message = "consul_backend_path output should be 'consul' when enabled"
  }
}

# -------------------------------------------------------------------------
# JWT auth backend + nomad-workloads role enabled by default
# -------------------------------------------------------------------------

run "baseline_jwt_auth_enabled" {
  command = plan

  # --- JWT auth backend created ---
  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 1
    error_message = "JWT auth backend should be created when jwt_auth_enabled is true"
  }

  # --- nomad-workloads role attached ---
  assert {
    condition     = length(vault_jwt_auth_backend_role.nomad_workloads) == 1
    error_message = "JWT auth role 'nomad-workloads' should be created"
  }

  # --- jwt_auth_path output reflects the fixed "jwt-nomad" path ---
  assert {
    condition     = output.jwt_auth_path == "jwt-nomad"
    error_message = "jwt_auth_path output should be 'jwt-nomad' when enabled"
  }

  # --- the default role carries the templated policy, so a job gets its own
  #     KV prefix without being named anywhere ---
  assert {
    condition     = contains(vault_jwt_auth_backend_role.nomad_workloads[0].token_policies, "nomad-workload-self")
    error_message = "the default role must carry nomad-workload-self so new jobs need no config"
  }
}

# -------------------------------------------------------------------------
# Database secrets disabled by default (off unless explicit opt-in)
# -------------------------------------------------------------------------

run "baseline_database_disabled_by_default" {
  command = plan

  # --- database secrets mount stays off without explicit enable ---
  assert {
    condition     = length(vault_database_secrets_mount.postgres) == 0
    error_message = "Database secrets mount should be off by default"
  }
}

# -------------------------------------------------------------------------
# PKI roles for_each fans out to the keys passed
# -------------------------------------------------------------------------

run "baseline_pki_roles_created" {
  command = plan

  variables {
    pki_roles = {
      traefik  = { allowed_domains = ["munchbox.cc"], max_ttl = "8760h", ttl = "720h" }
      postgres = { allowed_domains = ["postgres.consul"], max_ttl = "720h", ttl = "72h" }
    }
  }

  # --- two pki_roles keys -> two role resources ---
  assert {
    condition     = length(vault_pki_secret_backend_role.role) == 2
    error_message = "Both PKI roles should be created from for_each"
  }

  # --- traefik role key exists ---
  assert {
    condition     = contains(keys(vault_pki_secret_backend_role.role), "traefik")
    error_message = "PKI role 'traefik' should exist in the map"
  }

  # --- postgres role key exists ---
  assert {
    condition     = contains(keys(vault_pki_secret_backend_role.role), "postgres")
    error_message = "PKI role 'postgres' should exist in the map"
  }

  # --- pki_role_names output is keyed by every PKI role ---
  assert {
    condition     = toset(keys(output.pki_role_names)) == toset(["traefik", "postgres"])
    error_message = "pki_role_names output must list every PKI role key"
  }

  # --- each PKI role name maps to its key ---
  assert {
    condition     = output.pki_role_names["traefik"] == "traefik"
    error_message = "pki_role_names value should match the role key"
  }
}

# -------------------------------------------------------------------------
# vault_policies for_each fans out to the keys passed
# -------------------------------------------------------------------------

run "baseline_policies_created" {
  command = plan

  variables {
    # NOTE: "vault-cert-manager" is intentionally NOT used as a key here -- it
    # collides with the moved{} block in policies.tf (vault_policy.policy[...] ->
    # vault_policy.cert_manager[0]), which errors at plan when the source address
    # is re-declared via for_each. A neutral third key exercises the same fan-out.
    vault_policies = {
      "consul-token-read" = { policy = "path \"x\" { capabilities = [\"read\"] }" }
      "nomad-server"      = { policy = "path \"y\" { capabilities = [\"read\"] }" }
      "redis-acl"         = { policy = "path \"z\" { capabilities = [\"read\"] }" }
    }
  }

  # --- three vault_policies keys -> three policy resources ---
  assert {
    condition     = length(vault_policy.policy) == 3
    error_message = "All three policies should be created from for_each"
  }

  # --- consul-token-read key exists ---
  assert {
    condition     = contains(keys(vault_policy.policy), "consul-token-read")
    error_message = "Policy 'consul-token-read' should exist"
  }

  # --- policy_names lists the map keys plus nomad_workload_self, which rides
  #     on jwt_auth_enabled; nomad_workloads stays out without workload_secrets ---
  assert {
    condition     = toset(keys(output.policy_names)) == toset(["consul-token-read", "nomad-server", "redis-acl", "nomad_workload_self"])
    error_message = "policy_names must list every created policy"
  }

  # --- each policy name maps to its key ---
  assert {
    condition     = output.policy_names["nomad-server"] == "nomad-server"
    error_message = "policy_names value should match the policy key"
  }
}

# -------------------------------------------------------------------------
# disable_kv: KV mount is gated off when kv_enabled = false
# -------------------------------------------------------------------------

run "disable_kv" {
  command = plan

  variables {
    kv_enabled = false
  }

  # --- KV mount count drops to 0 when disabled ---
  assert {
    condition     = length(vault_mount.kv) == 0
    error_message = "KV mount should be skipped when kv_enabled = false"
  }
}

# -------------------------------------------------------------------------
# disable_consul_secrets gates the backend off
# -------------------------------------------------------------------------

run "disable_consul_secrets" {
  command = plan

  variables {
    consul_secrets_enabled = false
  }

  # --- consul backend count drops to 0 when disabled ---
  assert {
    condition     = length(vault_consul_secret_backend.consul) == 0
    error_message = "Consul backend should not be created when disabled"
  }
}

# -------------------------------------------------------------------------
# disable_jwt_auth: backend + role both off
# -------------------------------------------------------------------------

run "disable_jwt_auth" {
  command = plan

  variables {
    jwt_auth_enabled = false
  }

  # --- JWT backend drops to 0 ---
  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 0
    error_message = "JWT backend should not be created when disabled"
  }

  # --- JWT role drops to 0 ---
  assert {
    condition     = length(vault_jwt_auth_backend_role.nomad_workloads) == 0
    error_message = "JWT role should not be created when JWT is disabled"
  }

  # --- the self-scoped policy needs the backend's accessor, so it goes too ---
  assert {
    condition     = length(vault_policy.nomad_workload_self) == 0
    error_message = "nomad-workload-self should not be created without the JWT backend"
  }
}

# -------------------------------------------------------------------------
# Self-scoped workload policy templates on the JWT accessor
# -------------------------------------------------------------------------

run "workload_self_policy_templated" {
  command = plan

  # --- the accessor is provider-assigned, so the policy body is unknown at
  #     plan time unless it is pinned here ---
  override_resource {
    target          = vault_jwt_auth_backend.nomad[0]
    override_during = plan
    values = {
      accessor = "auth_jwt_mocktest"
    }
  }

  # --- created alongside the JWT backend ---
  assert {
    condition     = length(vault_policy.nomad_workload_self) == 1
    error_message = "nomad-workload-self should be created when JWT auth and policies are enabled"
  }

  # --- grants the job's own prefix and its children, both templated ---
  assert {
    condition = alltrue([
      strcontains(vault_policy.nomad_workload_self[0].policy, "path \"secret/data/{{identity.entity.aliases."),
      strcontains(vault_policy.nomad_workload_self[0].policy, ".name}}/*\" {"),
    ])
    error_message = "nomad-workload-self must template the job's own KV prefix and its children"
  }

  # --- interpolates the live accessor rather than a mount path ---
  assert {
    condition     = !strcontains(vault_policy.nomad_workload_self[0].policy, "aliases.jwt-nomad.")
    error_message = "the template must use the backend accessor, not the mount path"
  }

  # --- carries none of the privileged grants the static policy hands out ---
  assert {
    condition = alltrue([
      !strcontains(vault_policy.nomad_workload_self[0].policy, "ssh-client-signer"),
      !strcontains(vault_policy.nomad_workload_self[0].policy, "consul/creds"),
      !strcontains(vault_policy.nomad_workload_self[0].policy, "postgres-shared"),
    ])
    error_message = "nomad-workload-self must not grant SSH signing, Consul creds, or shared Postgres"
  }
}

# -------------------------------------------------------------------------
# enable_database_secrets with two roles fans out per key
# -------------------------------------------------------------------------

run "enable_database_secrets" {
  command = plan

  variables {
    database_secrets_enabled = true
    database_roles = {
      temporal = { creation_statements = ["CREATE ROLE x;"] }
      kanboard = { creation_statements = ["CREATE ROLE y;"] }
    }
  }

  # --- database mount fires when explicitly enabled ---
  assert {
    condition     = length(vault_database_secrets_mount.postgres) == 1
    error_message = "Database secrets mount should be created when enabled"
  }

  # --- two roles -> two role resources via for_each ---
  assert {
    condition     = length(vault_database_secret_backend_role.role) == 2
    error_message = "Both database roles should be created from for_each"
  }

  # --- 'temporal' key exists in the role map ---
  assert {
    condition     = contains(keys(vault_database_secret_backend_role.role), "temporal")
    error_message = "Database role 'temporal' should exist"
  }

  # --- database_backend_path output reflects the fixed "database" path ---
  assert {
    condition     = output.database_backend_path == "database"
    error_message = "database_backend_path should be 'database' when enabled"
  }

  # --- database_role_names output is keyed by every database role ---
  assert {
    condition     = toset(keys(output.database_role_names)) == toset(["temporal", "kanboard"])
    error_message = "database_role_names must list every database role key"
  }

  # --- each database role name maps to its key ---
  assert {
    condition     = output.database_role_names["temporal"] == "temporal"
    error_message = "database_role_names value should match the role key"
  }
}

# -------------------------------------------------------------------------
# disable_pki_roles: for_each map is empty regardless of var.pki_roles
# -------------------------------------------------------------------------

run "disable_pki_roles" {
  command = plan

  variables {
    pki_roles_enabled = false
    pki_roles = {
      traefik = { allowed_domains = ["munchbox.cc"], max_ttl = "8760h", ttl = "720h" }
    }
  }

  # --- pki_roles input ignored when feature flag is off ---
  assert {
    condition     = length(vault_pki_secret_backend_role.role) == 0
    error_message = "No PKI roles should be created when pki_roles_enabled = false"
  }
}

# -------------------------------------------------------------------------
# disable_policies: for_each map empty + named nomad_workloads off
# -------------------------------------------------------------------------

run "disable_policies" {
  command = plan

  variables {
    policies_enabled = false
    vault_policies = {
      "p1" = { policy = "path \"x\" { capabilities = [\"read\"] }" }
    }
  }

  # --- vault_policies map yields zero resources when feature disabled ---
  assert {
    condition     = length(vault_policy.policy) == 0
    error_message = "No vault policies should be created when policies_enabled = false"
  }

  # --- nomad_workloads named policy also drops to zero ---
  assert {
    condition     = length(vault_policy.nomad_workloads) == 0
    error_message = "Nomad workloads policy should be off when policies_enabled = false"
  }
}

# -------------------------------------------------------------------------
# database_roles subset: only the provided key creates a role
# -------------------------------------------------------------------------

run "database_roles_subset" {
  command = plan

  variables {
    database_secrets_enabled = true
    database_roles = {
      temporal = { creation_statements = ["CREATE ROLE x;"] }
    }
  }

  # --- one role input -> one role resource ---
  assert {
    condition     = length(vault_database_secret_backend_role.role) == 1
    error_message = "Only one role should be created when only one key is in the map"
  }

  # --- the surviving key is the one we provided ---
  assert {
    condition     = contains(keys(vault_database_secret_backend_role.role), "temporal")
    error_message = "The remaining role key should be 'temporal'"
  }
}

# -------------------------------------------------------------------------
# Custom workload_secrets list is accepted (nomad_workloads still created)
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# The shared workloads policy no longer carries the privileged grants
# -------------------------------------------------------------------------

run "workloads_policy_drops_privileged_grants" {
  command = plan

  variables {
    ssh_ca_enabled   = true
    workload_secrets = ["traefik", "grafana"]
  }

  # --- SSH client signing belongs to the one worker that needs it ---
  assert {
    condition     = !strcontains(vault_policy.nomad_workloads[0].policy, "ssh-client-signer")
    error_message = "nomad-workloads must not grant SSH client certificate signing"
  }

  # --- no dynamic Consul token minting; nothing consumes it ---
  assert {
    condition     = !strcontains(vault_policy.nomad_workloads[0].policy, "consul/creds")
    error_message = "nomad-workloads must not grant Consul dynamic credentials"
  }

  # --- the KV paths it does exist for are still generated ---
  assert {
    condition = alltrue([
      strcontains(vault_policy.nomad_workloads[0].policy, "path \"secret/data/traefik\""),
      strcontains(vault_policy.nomad_workloads[0].policy, "path \"secret/data/grafana\""),
    ])
    error_message = "nomad-workloads must still generate a path per workload secret"
  }
}

# -------------------------------------------------------------------------
# Per-job extra-grant policies fan out from workload_extra_secrets
# -------------------------------------------------------------------------

run "workload_extra_secrets_generate_policies" {
  command = plan

  variables {
    workload_extra_secrets = {
      gitgogit = { secrets = ["forgejo"] }
      patroni = {
        secrets     = ["postgres-shared/root"]
        extra_paths = { "pki_int/issue/postgres" = ["create", "update"] }
      }
    }
  }

  # --- one policy per map key ---
  assert {
    condition     = length(vault_policy.workload_extra) == 2
    error_message = "each workload_extra_secrets entry should generate a policy"
  }

  # --- named <job>-secrets so it cannot collide with a hand-written policy ---
  assert {
    condition     = vault_policy.workload_extra["gitgogit"].name == "gitgogit-secrets"
    error_message = "generated policies should be named <job>-secrets"
  }

  # --- KV names become read grants under secret/data/ ---
  assert {
    condition     = strcontains(vault_policy.workload_extra["gitgogit"].policy, "path \"secret/data/forgejo\" {")
    error_message = "secrets entries should grant read on secret/data/<name>"
  }

  # --- extra_paths are written verbatim with their own capabilities ---
  assert {
    condition = alltrue([
      strcontains(vault_policy.workload_extra["patroni"].policy, "path \"pki_int/issue/postgres\" {"),
      strcontains(vault_policy.workload_extra["patroni"].policy, "[\"create\",\"update\"]"),
    ])
    error_message = "extra_paths should be emitted verbatim with their capabilities"
  }

  # --- a job grants nothing another job named ---
  assert {
    condition     = !strcontains(vault_policy.workload_extra["gitgogit"].policy, "postgres-shared")
    error_message = "a generated policy must carry only its own job's paths"
  }
}

# -------------------------------------------------------------------------
# No extra grants declared -> no generated policies
# -------------------------------------------------------------------------

run "no_workload_extra_secrets" {
  command = plan

  assert {
    condition     = length(vault_policy.workload_extra) == 0
    error_message = "no policies should be generated when the map is empty"
  }
}

run "custom_workload_secrets" {
  command = plan

  variables {
    workload_secrets = ["custom-app", "another-secret"]
  }

  # --- workload_secrets > 0 triggers the nomad_workloads policy ---
  assert {
    condition     = length(vault_policy.nomad_workloads) == 1
    error_message = "Nomad workloads policy should still be created with custom secret list"
  }

  # --- policy_names output includes the merged nomad_workloads entry ---
  assert {
    condition     = output.policy_names["nomad_workloads"] == "nomad-workloads"
    error_message = "policy_names must include nomad_workloads when workload_secrets is set"
  }
}

# -------------------------------------------------------------------------
# Minimal config: every flag off, everything count = 0
# -------------------------------------------------------------------------

run "minimal_configuration" {
  command = plan

  variables {
    kv_enabled             = false
    consul_secrets_enabled = false
    jwt_auth_enabled       = false
    pki_roles_enabled      = false
    policies_enabled       = false
  }

  # --- no KV mount ---
  assert {
    condition     = length(vault_mount.kv) == 0
    error_message = "No KV with minimal config"
  }

  # --- no consul backend ---
  assert {
    condition     = length(vault_consul_secret_backend.consul) == 0
    error_message = "No Consul backend with minimal config"
  }

  # --- no JWT auth ---
  assert {
    condition     = length(vault_jwt_auth_backend.nomad) == 0
    error_message = "No JWT auth with minimal config"
  }

  # --- no PKI roles ---
  assert {
    condition     = length(vault_pki_secret_backend_role.role) == 0
    error_message = "No PKI roles with minimal config"
  }

  # --- no nomad_workloads named policy ---
  assert {
    condition     = length(vault_policy.nomad_workloads) == 0
    error_message = "No nomad_workloads policy with minimal config"
  }
}
