# -----------------------------------------------------------------------------
# object-storage-ibm module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts COS instance + bucket + resource_key composition: instance name/plan
# propagate, bucket region + storage_class wire through, the resource_key
# requests HMAC params, and the key name follows the <bucket>-s3-access
# convention.
# -----------------------------------------------------------------------------

mock_provider "ibm" {
  mock_data "ibm_resource_group" {
    defaults = { id = "rg-mock" }
  }
}

variables {
  ibmcloud_api_key = "mock-api-key"

  resource_group = "Default"
  instance_name  = "test-cos"
  bucket_name    = "test-bucket"
  region         = "us-east"
  storage_class  = "smart"
  plan           = "standard"
  tags           = { project = "munchbox", purpose = "test" }
}

# -------------------------------------------------------------------------
# COS instance: name + plan + service propagate from inputs
# -------------------------------------------------------------------------

run "instance_inputs_propagate" {
  command = plan

  # --- display name comes from var.instance_name ---
  assert {
    condition     = ibm_resource_instance.cos.name == var.instance_name
    error_message = "COS instance name must match var.instance_name"
  }

  # --- service plan comes from var.plan ---
  assert {
    condition     = ibm_resource_instance.cos.plan == var.plan
    error_message = "COS instance plan must match var.plan"
  }

  # --- service is hardcoded cloud-object-storage ---
  assert {
    condition     = ibm_resource_instance.cos.service == "cloud-object-storage"
    error_message = "COS instance service must be cloud-object-storage"
  }
}

# -------------------------------------------------------------------------
# Bucket: name + region + storage_class wire through
# -------------------------------------------------------------------------

run "bucket_inputs_propagate" {
  command = plan

  # --- bucket_name flows to resource ---
  assert {
    condition     = ibm_cos_bucket.this.bucket_name == var.bucket_name
    error_message = "bucket_name must match var.bucket_name"
  }

  # --- region maps to region_location attribute ---
  assert {
    condition     = ibm_cos_bucket.this.region_location == var.region
    error_message = "bucket region_location must match var.region"
  }

  # --- storage_class flows to resource ---
  assert {
    condition     = ibm_cos_bucket.this.storage_class == var.storage_class
    error_message = "bucket storage_class must match var.storage_class"
  }
}

# -------------------------------------------------------------------------
# resource_key requests HMAC + Manager (required for S3-compat access)
# -------------------------------------------------------------------------

run "resource_key_hmac" {
  command = plan

  # --- role is Manager (gives full read/write on the bucket) ---
  assert {
    condition     = ibm_resource_key.s3_credentials.role == "Manager"
    error_message = "resource_key role must be Manager"
  }

  # --- HMAC parameter requested so the key exposes cos_hmac_keys ---
  assert {
    condition     = ibm_resource_key.s3_credentials.parameters["HMAC"] == "true"
    error_message = "resource_key parameters.HMAC must be \"true\""
  }
}

# -------------------------------------------------------------------------
# Key name follows the <bucket>-s3-access convention
# -------------------------------------------------------------------------

run "resource_key_name" {
  command = plan

  # --- name uses bucket_name as prefix; -s3-access suffix is constant ---
  assert {
    condition     = ibm_resource_key.s3_credentials.name == "${var.bucket_name}-s3-access"
    error_message = "resource_key name must follow <bucket>-s3-access convention"
  }
}
