# -----------------------------------------------------------------------------
# FUNCTIONS-OCI Module Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# vault_data carries everything the consumer needs to sign and send requests:
# the private key, the tenancy, user and fingerprint that name it, and the
# region. Each function's OCID travels with them as function_<name>, so a
# caller that invokes one by OCID reads one path. Keyed by the consumer, as
# every generator's vault_data is.
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "The consumer's credentials and coordinates, for the vault-secrets leaf to write"
  sensitive   = true

  value = {
    (var.name) = merge(
      {
        private_key    = tls_private_key.this.private_key_pem
        tenancy        = var.tenancy_ocid
        user           = oci_identity_user.this.id
        fingerprint    = oci_identity_api_key.this.fingerprint
        region         = var.region
        compartment_id = oci_identity_compartment.this.id
        application_id = oci_functions_application.this.id
      },
      { for name, f in oci_functions_function.this : "function_${name}" => f.id },
    )
  }
}

output "function_ids" {
  description = "Function OCIDs, keyed by function name"
  value       = { for name, f in oci_functions_function.this : name => f.id }
}

output "application_id" {
  description = "The application's OCID"
  value       = oci_functions_application.this.id
}
