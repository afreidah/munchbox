# -------------------------------------------------------------------------------
# Object Storage Module - IBM Cloud
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions an IBM Cloud Object Storage instance and bucket with S3-compatible
# HMAC credentials. Creates a resource key with HMAC parameters for S3 API access.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# DATA SOURCES
# -------------------------------------------------------------------------

data "ibm_resource_group" "this" {
  name = var.resource_group
}

# -------------------------------------------------------------------------
# COS INSTANCE
# -------------------------------------------------------------------------

resource "ibm_resource_instance" "cos" {
  name              = var.instance_name
  service           = "cloud-object-storage"
  plan              = var.plan
  location          = "global"
  resource_group_id = data.ibm_resource_group.this.id

  tags = [for k, v in var.tags : "${k}:${v}"]
}

# -------------------------------------------------------------------------
# OBJECT STORAGE BUCKET
# -------------------------------------------------------------------------

resource "ibm_cos_bucket" "this" {
  bucket_name          = var.bucket_name
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = var.region
  storage_class        = var.storage_class
}

# -------------------------------------------------------------------------
# S3 COMPATIBILITY CREDENTIALS
# -------------------------------------------------------------------------

# HMAC keys provide S3-compatible access to IBM Cloud Object Storage.
resource "ibm_resource_key" "s3_credentials" {
  name                 = "${var.bucket_name}-s3-access"
  resource_instance_id = ibm_resource_instance.cos.id
  role                 = "Manager"
  parameters           = { "HMAC" = true }
}
