# -----------------------------------------------------------------------------
# OBJECT STORAGE ENV HELPER  (every s3-orchestrator bucket backend)
# -----------------------------------------------------------------------------
#
# One helper for all s3-orchestrator bucket leaves. The leaf dir name is the
# provider key: it selects the module and its inputs
# (root.hcl s3_orchestrator_buckets[<provider>]). Native providers use
# object-storage-<provider>; pure S3 endpoints share object-storage-s3compat
# (aws); MinIO/path-less S3 use object-storage-minio (aminueza/minio). Provider
# creds and scanner suppressions are emitted per-provider from the maps.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  root     = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  provider = basename(get_terragrunt_dir())
  # Vault stores fields under an underscore key (minio-arm2 -> minio_arm2_s3_*)
  vault_key = replace(local.provider, "-", "_")

  # --- S3-compatible-only backends (no native provider) ---
  #     s3compat: aws_s3_bucket.  minio: aminueza/minio (self-hosted MinIO + path-less S3-compat)
  s3compat_providers = ["e2", "c2"]
  minio_providers    = ["minio", "minio-arm2", "g3"]
  is_s3compat        = contains(local.s3compat_providers, local.provider)
  is_minio           = contains(local.minio_providers, local.provider)
  # supabase: management-API provider (path-prefixed S3 endpoint, no bucket sub-APIs)
  is_supabase = local.provider == "supabase"
  module_name = local.is_s3compat ? "object-storage-s3compat" : local.is_minio ? "object-storage-minio" : "object-storage-${local.provider}"

  # --- native providers whose creds live in secret/s3-orchestrator (S3-style key/secret) ---
  vault_cred_providers = {
    b2     = { key_arg = "application_key_id", secret_arg = "application_key" }
    tigris = { key_arg = "access_key", secret_arg = "secret_key" }
  }
  vcp        = lookup(local.vault_cred_providers, local.provider, null)
  vcp_key    = try(local.vcp.key_arg, "")
  vcp_secret = try(local.vcp.secret_arg, "")

  # --- per-provider scanner suppressions (accepted homelab gaps on managed-as-is buckets) ---
  s3compat_checkov = ["CKV2_AWS_6", "CKV2_AWS_61", "CKV2_AWS_62", "CKV_AWS_144", "CKV_AWS_145", "CKV_AWS_18", "CKV_AWS_19", "CKV_AWS_20", "CKV_AWS_21", "CKV_AWS_57", "CKV_AWS_93"]
  # trivy equivalents (public-access-block, logging, versioning, CMK) on the same managed-as-is S3-compat buckets
  s3compat_trivy = ["AVD-AWS-0086", "AVD-AWS-0087", "AVD-AWS-0089", "AVD-AWS-0090", "AVD-AWS-0091", "AVD-AWS-0093", "AVD-AWS-0094", "AVD-AWS-0132"]
  checkov_skips = {
    oci = ["CKV_OCI_7", "CKV_OCI_8", "CKV_OCI_9"]
    gcp = ["CKV_GCP_29", "CKV_GCP_62", "CKV_GCP_78", "CKV_GCP_114"]
    e2  = local.s3compat_checkov
    c2  = local.s3compat_checkov
  }
  trivy_ignores = {
    gcp = ["AVD-GCP-0002", "AVD-GCP-0066", "AVD-GCP-0077", "AVD-GCP-0078"]
    e2  = local.s3compat_trivy
    c2  = local.s3compat_trivy
  }
  my_checkov = lookup(local.checkov_skips, local.provider, [])
  my_trivy   = lookup(local.trivy_ignores, local.provider, [])
}

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//${local.module_name}"
}

# --- native vault-sourced provider creds (b2/tigris) ---
generate "provider_creds" {
  path      = "provider_creds.tf"
  if_exists = "overwrite"
  disable   = local.vcp == null
  contents  = <<-EOF
    data "vault_kv_secret_v2" "s3_orchestrator" {
      mount = "secret"
      name  = "s3-orchestrator"
    }

    provider "${local.provider}" {
      ${local.vcp_key}    = data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_access_key"]
      ${local.vcp_secret} = data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_secret_key"]
    }
  EOF
}

# --- generic S3-compatible aws provider; endpoint + creds from Vault (e2/c2) ---
generate "provider_s3compat" {
  path      = "provider_s3compat.tf"
  if_exists = "overwrite"
  disable   = !local.is_s3compat
  contents  = <<-EOF
    data "vault_kv_secret_v2" "s3_orchestrator" {
      mount = "secret"
      name  = "s3-orchestrator"
    }

    provider "aws" {
      region     = lookup(data.vault_kv_secret_v2.s3_orchestrator.data, "${local.vault_key}_s3_region", "us-east-1")
      access_key = data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_access_key"]
      secret_key = data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_secret_key"]

      skip_credentials_validation = true
      skip_requesting_account_id  = true
      skip_metadata_api_check     = true
      skip_region_validation      = true
      s3_use_path_style           = true

      endpoints {
        s3 = data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_endpoint"]
      }
    }
  EOF
}

# --- minio provider for self-hosted MinIO + path-less S3-compat (minio/minio-arm2) ---
generate "provider_minio" {
  path      = "provider_minio.tf"
  if_exists = "overwrite"
  disable   = !local.is_minio
  contents  = <<-EOF
    data "vault_kv_secret_v2" "s3_orchestrator" {
      mount = "secret"
      name  = "s3-orchestrator"
    }

    provider "minio" {
      minio_server   = replace(replace(data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_endpoint"], "https://", ""), "http://", "")
      minio_user     = data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_access_key"]
      minio_password = data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_secret_key"]
      minio_region   = lookup(data.vault_kv_secret_v2.s3_orchestrator.data, "${local.vault_key}_s3_region", "us-east-1")
      minio_ssl      = startswith(data.vault_kv_secret_v2.s3_orchestrator.data["${local.vault_key}_s3_endpoint"], "https")
      s3_compat_mode = true
    }
  EOF
}

# --- supabase management-API provider; PAT (sbp_...) from Vault ---
generate "provider_supabase" {
  path      = "provider_supabase.tf"
  if_exists = "overwrite"
  disable   = !local.is_supabase
  contents  = <<-EOF
    data "vault_kv_secret_v2" "s3_orchestrator" {
      mount = "secret"
      name  = "s3-orchestrator"
    }

    provider "supabase" {
      access_token = data.vault_kv_secret_v2.s3_orchestrator.data["supabase_access_token"]
    }
  EOF
}

generate "checkov_config" {
  path      = ".checkov.yaml"
  if_exists = "overwrite"
  disable   = length(local.my_checkov) == 0
  contents  = "skip-check:\n${join("\n", formatlist("  - %s", local.my_checkov))}\n"
}

generate "trivy_ignore" {
  path      = ".trivyignore"
  if_exists = "overwrite"
  disable   = length(local.my_trivy) == 0
  contents  = "${join("\n", local.my_trivy)}\n"
}

inputs = local.root.locals.s3_orchestrator_buckets[local.provider]
