# -------------------------------------------------------------------------------
# Object Storage Module Outputs - IBM Cloud
#
# Project: Munchbox / Author: Alex Freidah
#
# Outputs include the S3-compatible endpoint URL and HMAC credentials needed to
# configure the S3 proxy backend.
# -------------------------------------------------------------------------------

output "bucket_name" {
  description = "Name of the created bucket"
  value       = ibm_cos_bucket.this.bucket_name
}

output "instance_id" {
  description = "COS instance ID"
  value       = ibm_resource_instance.cos.id
}

output "s3_endpoint" {
  description = "S3-compatible endpoint URL for the bucket"
  value       = "https://s3.${var.region}.cloud-object-storage.appdomain.cloud"
}

output "s3_access_key" {
  description = "S3 access key ID (HMAC)"
  value       = ibm_resource_key.s3_credentials.credentials["cos_hmac_keys.access_key_id"]
}

output "s3_secret_key" {
  description = "S3 secret access key (HMAC)"
  value       = ibm_resource_key.s3_credentials.credentials["cos_hmac_keys.secret_access_key"]
  sensitive   = true
}

output "s3_bucket_url" {
  description = "Full S3 URL to the bucket"
  value       = "https://s3.${var.region}.cloud-object-storage.appdomain.cloud/${ibm_cos_bucket.this.bucket_name}"
}
