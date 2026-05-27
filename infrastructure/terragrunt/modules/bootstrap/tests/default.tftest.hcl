# -----------------------------------------------------------------------------
# bootstrap (wrapper) module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts create_network gates the network sub-module count, the chef vault
# data sources resolve to the configured mount/name, and the compute
# sub-module (which has NO count) wires through with the right provider_type.
# -----------------------------------------------------------------------------

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = { id = "ami-mock" }
  }
}

mock_provider "oci" {
  mock_data "oci_identity_availability_domains" {
    defaults = { availability_domains = [{ name = "MockAD-1" }] }
  }
  mock_data "oci_core_images" {
    defaults = { images = [{ id = "ocid1.image..mock" }] }
  }
}

mock_provider "proxmox" {}

mock_provider "vault" {
  mock_data "vault_kv_secret_v2" {
    defaults = {
      data = {
        pem   = "-----BEGIN RSA PRIVATE KEY-----\nmock\n-----END RSA PRIVATE KEY-----"
        value = "mock-data-bag-secret"
      }
    }
  }
}

variables {
  name                             = "test-node"
  provider_type                    = "oci"
  cpu                              = 2
  memory_gb                        = 4
  disk_gb                          = 50
  ssh_public_key                   = "ssh-ed25519 AAAA test"
  wireguard_private_key            = "mock-private-key"
  wireguard_address                = "10.200.0.99"
  wireguard_server_public_key      = "mock-server-key"
  wireguard_endpoint               = "home.example.com:51820"
  chef_validator_vault_mount       = "secret"
  chef_validator_vault_name        = "cinc/validator"
  chef_validator_vault_field       = "pem"
  chef_data_bag_secret_vault_mount = "secret"
  chef_data_bag_secret_vault_name  = "cinc/encrypted_data_bag_secret"
  chef_data_bag_secret_vault_field = "value"
  chef_server_url                  = "https://cinc-server.example.com"
  chef_validator_client_name       = "test-validator"
  chef_node_name                   = "testnode"
  chef_run_list                    = "role[test]"
  munchbox_root_ca                 = "-----BEGIN CERTIFICATE-----\nmock\n-----END CERTIFICATE-----"
  munchbox_intermediate_ca         = "-----BEGIN CERTIFICATE-----\nmock\n-----END CERTIFICATE-----"
  oci_config = {
    compartment_id      = "ocid1.compartment.oc1..mock"
    availability_domain = "1"
    subnet_id           = "ocid1.subnet.oc1..mock"
  }
}

# -------------------------------------------------------------------------
# create_network = true -> network sub-module fires
# -------------------------------------------------------------------------

run "network_created_when_enabled" {
  command = plan

  variables {
    create_network = true
    vpc_cidr       = "10.100.0.0/16"
  }

  # --- network sub-module count = 1 when create_network is true ---
  assert {
    condition     = length(module.network) == 1
    error_message = "network sub-module should fire when create_network = true"
  }
}

# -------------------------------------------------------------------------
# create_network = false -> network sub-module skipped
# -------------------------------------------------------------------------

run "network_skipped_when_disabled" {
  command = plan

  variables {
    create_network             = false
    existing_subnet_id         = "ocid1.subnet.oc1..mock"
    existing_security_group_id = "ocid1.securitylist.oc1..mock"
  }

  # --- network sub-module count = 0 when create_network is false ---
  assert {
    condition     = length(module.network) == 0
    error_message = "network sub-module should be skipped when create_network = false"
  }
}

# -------------------------------------------------------------------------
# compute sub-module wires through with the requested provider_type
# (compute has no count, so length() is invalid — use a normalized output)
# -------------------------------------------------------------------------

run "compute_wires_provider_type" {
  command = plan

  variables {
    create_network             = false
    existing_subnet_id         = "ocid1.subnet.oc1..mock"
    existing_security_group_id = "ocid1.securitylist.oc1..mock"
  }

  # --- compute.provider_type echoes var.provider_type from bootstrap ---
  assert {
    condition     = module.compute.provider_type == var.provider_type
    error_message = "compute sub-module should be wired with var.provider_type"
  }
}

# -------------------------------------------------------------------------
# chef data sources resolve with the configured mount/name
# -------------------------------------------------------------------------

run "chef_data_source_targets" {
  command = plan

  variables {
    create_network             = false
    existing_subnet_id         = "ocid1.subnet.oc1..mock"
    existing_security_group_id = "ocid1.securitylist.oc1..mock"
  }

  # --- chef_validator data source reads from configured mount ---
  assert {
    condition     = data.vault_kv_secret_v2.chef_validator.mount == "secret"
    error_message = "chef_validator must be read from configured mount"
  }

  # --- chef_validator data source uses the configured secret name ---
  assert {
    condition     = data.vault_kv_secret_v2.chef_validator.name == "cinc/validator"
    error_message = "chef_validator name must match var"
  }
}
