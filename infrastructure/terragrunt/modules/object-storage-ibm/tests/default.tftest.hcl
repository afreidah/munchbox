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

# -------------------------------------------------------------------------
# OUTPUTS: every declared output is asserted at least once
# -------------------------------------------------------------------------

run "outputs" {
  command = plan

  # --- make computed ids/credentials known during plan so outputs resolve ---
  override_resource {
    target          = ibm_resource_instance.cos
    override_during = plan
    values          = { id = "crn:v1:bluemix:public:cloud-object-storage:global:a/00000000000000000000000000000000:00000000-0000-0000-0000-000000000000::" }
  }
  override_resource {
    target          = ibm_resource_key.s3_credentials
    override_during = plan
    values = {
      credentials = {
        "cos_hmac_keys.access_key_id"     = "mock-access-key-id"
        "cos_hmac_keys.secret_access_key" = "mock-secret-key"
      }
    }
  }

  # --- bucket_name mirrors the input ---
  assert {
    condition     = output.bucket_name == var.bucket_name
    error_message = "output.bucket_name must equal var.bucket_name"
  }

  # --- instance_id is the computed COS instance id (mocked) ---
  assert {
    condition     = output.instance_id == "crn:v1:bluemix:public:cloud-object-storage:global:a/00000000000000000000000000000000:00000000-0000-0000-0000-000000000000::"
    error_message = "output.instance_id must be the COS instance id"
  }

  # --- s3_endpoint is derived from var.region ---
  assert {
    condition     = output.s3_endpoint == "https://s3.${var.region}.cloud-object-storage.appdomain.cloud"
    error_message = "output.s3_endpoint must be the region-derived endpoint URL"
  }

  # --- s3_bucket_url is endpoint + bucket name ---
  assert {
    condition     = output.s3_bucket_url == "https://s3.${var.region}.cloud-object-storage.appdomain.cloud/${var.bucket_name}"
    error_message = "output.s3_bucket_url must be endpoint + bucket_name"
  }

  # --- s3_access_key is the HMAC access key id (mocked credentials map) ---
  assert {
    condition     = nonsensitive(output.s3_access_key) == "mock-access-key-id"
    error_message = "output.s3_access_key must be the HMAC access key id"
  }

  # --- s3_secret_key is the HMAC secret access key (mocked credentials map) ---
  assert {
    condition     = nonsensitive(output.s3_secret_key) == "mock-secret-key"
    error_message = "output.s3_secret_key must be the HMAC secret access key"
  }
}
