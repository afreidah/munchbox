# -----------------------------------------------------------------------------
# KMS MODULE - INPUT VARIABLES - ORACLE CLOUD
# -----------------------------------------------------------------------------
#
# This file defines all configurable parameters for the OCI KMS module,
# including compartment placement, vault configuration, key settings, and
# protection mode selection.
#
# Variable Categories:
#   - Compartment: OCI compartment for resource placement
#   - Vault Configuration: KMS vault name and type
#   - Key Configuration: Master encryption key settings
#   - Tagging: Resource tags for organization and billing
#
# Cost Considerations:
#   - DEFAULT vault type: Free (shared HSM infrastructure)
#   - VIRTUAL_PRIVATE vault type: Dedicated HSM ($$$)
#   - SOFTWARE protection mode: Free
#   - HSM protection mode: Per key version billing
#
# Recommendations:
#   - Use DEFAULT + SOFTWARE for cost-effective auto-unseal
#   - Use VIRTUAL_PRIVATE + HSM for regulatory compliance (FIPS 140-2 Level 3)
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# COMPARTMENT CONFIGURATION
# -----------------------------------------------------------------------------

variable "compartment_id" {
  description = "OCI compartment OCID where KMS resources will be created"
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.compartment_id)) || can(regex("^ocid1\\.tenancy\\.", var.compartment_id))
    error_message = "Compartment ID must be a valid OCI compartment or tenancy OCID."
  }
}

# -----------------------------------------------------------------------------
# VAULT CONFIGURATION
# -----------------------------------------------------------------------------

variable "vault_display_name" {
  description = "Display name for the OCI KMS vault (container for encryption keys)"
  type        = string
  default     = "munchbox-vault-unseal"

  validation {
    condition     = length(var.vault_display_name) >= 1 && length(var.vault_display_name) <= 100
    error_message = "Vault display name must be between 1 and 100 characters."
  }
}

variable "vault_type" {
  description = "Type of KMS vault: DEFAULT (shared HSM, free) or VIRTUAL_PRIVATE (dedicated HSM)"
  type        = string
  default     = "DEFAULT"

  validation {
    condition     = contains(["DEFAULT", "VIRTUAL_PRIVATE"], var.vault_type)
    error_message = "Vault type must be DEFAULT or VIRTUAL_PRIVATE."
  }
}

# -----------------------------------------------------------------------------
# KEY CONFIGURATION
# -----------------------------------------------------------------------------

variable "key_display_name" {
  description = "Display name for the master encryption key used by HashiCorp Vault"
  type        = string
  default     = "vault-auto-unseal-key"

  validation {
    condition     = length(var.key_display_name) >= 1 && length(var.key_display_name) <= 100
    error_message = "Key display name must be between 1 and 100 characters."
  }
}

variable "protection_mode" {
  description = "Key protection mode: SOFTWARE (free, server-protected) or HSM (hardware-backed, per-version cost)"
  type        = string
  default     = "SOFTWARE"

  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.protection_mode)
    error_message = "Protection mode must be SOFTWARE or HSM."
  }
}

# -----------------------------------------------------------------------------
# TAGGING
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Freeform tags to apply to all KMS resources for organization and cost tracking"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# AUTO-UNSEAL IAM PRINCIPAL
# -----------------------------------------------------------------------------

variable "tenancy_ocid" {
  description = "Tenancy OCID; the auto-unseal IAM user and group are created in the tenancy root."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.tenancy\\.", var.tenancy_ocid))
    error_message = "tenancy_ocid must be a valid OCI tenancy OCID."
  }
}

variable "region" {
  description = "OCI region for the auto-unseal API-key principal; surfaced for the Vault seal OCI config."
  type        = string
}

variable "unseal_user_name" {
  description = "Name of the dedicated OCI user that Vault uses to call OCI KMS for auto-unseal."
  type        = string
  default     = "vault-auto-unseal"
}

variable "unseal_group_name" {
  description = "Name of the OCI group granted use of the auto-unseal key."
  type        = string
  default     = "vault-auto-unseal"
}

variable "unseal_policy_name" {
  description = "Name of the OCI policy scoping the group to key-use on the auto-unseal key only."
  type        = string
  default     = "vault-auto-unseal-key-use"
}

variable "unseal_user_email" {
  description = "Primary email for the auto-unseal OCI user; required by Identity Domains/IDCS tenancies."
  type        = string
  default     = "alex.freidah@gmail.com"
}
