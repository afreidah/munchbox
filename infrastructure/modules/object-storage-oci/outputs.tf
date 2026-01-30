# -------------------------------------------------------------------------------
# Object Storage Module Outputs - Oracle Cloud
#
# Project: Munchbox / Author: Alex Freidah
#
# Outputs include the S3-compatible endpoint URL and credentials needed to
# configure the S3 proxy backend.
# -------------------------------------------------------------------------------

output "bucket_name" {
  description = "Name of the created bucket"
  value       = oci_objectstorage_bucket.this.name
}

output "bucket_namespace" {
  description = "Object Storage namespace"
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "s3_endpoint" {
  description = "S3-compatible endpoint URL for the bucket"
  value       = "https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

output "s3_access_key" {
  description = "S3 access key ID (Customer Secret Key ID)"
  value       = oci_identity_customer_secret_key.s3_credentials.id
}

output "s3_secret_key" {
  description = "S3 secret access key (Customer Secret Key)"
  value       = oci_identity_customer_secret_key.s3_credentials.key
  sensitive   = true
}

output "s3_bucket_url" {
  description = "Full S3 URL to the bucket"
  value       = "https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${var.region}.oraclecloud.com/${oci_objectstorage_bucket.this.name}"
}
