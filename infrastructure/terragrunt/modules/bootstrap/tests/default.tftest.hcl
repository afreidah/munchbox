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
# NOTE: there is intentionally NO create_network = true run here.
#
# With create_network = true the ../network sub-module is pulled into the
# config graph, and that sub-module (via ../networking + ../security-group)
# requires the hashicorp/aws provider, which bootstrap's versions.tf does not
# declare. Under terraform 1.15 + aws provider v6 this forces the aws provider
# to configure and call STS GetCallerIdentity even when its resources are
# count=0, which fails in this sandbox (403). The sibling `network` module's
# own tests fail identically -- it is a pre-existing, environment-level issue,
# not fixable from a test file (would require editing versions.tf).
#
# All network-related OUTPUTS are still fully covered below via the
# create_network = false path (network_id == null, network == null, plus
# subnet_id / security_group_id falling back to the existing_* inputs).
# -------------------------------------------------------------------------

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

  # --- OUTPUT: network_id is null when network not created ---
  assert {
    condition     = output.network_id == null
    error_message = "output.network_id must be null when create_network = false"
  }

  # --- OUTPUT: raw network object is null when network not created ---
  assert {
    condition     = output.network == null
    error_message = "output.network must be null when create_network = false"
  }

  # --- OUTPUT: subnet_id falls back to existing_subnet_id ---
  assert {
    condition     = output.subnet_id == "ocid1.subnet.oc1..mock"
    error_message = "output.subnet_id must fall back to existing_subnet_id"
  }

  # --- OUTPUT: security_group_id falls back to existing_security_group_id ---
  assert {
    condition     = output.security_group_id == "ocid1.securitylist.oc1..mock"
    error_message = "output.security_group_id must fall back to existing_security_group_id"
  }

  # --- OUTPUT: node identity / cluster scalars echo input vars + defaults ---
  assert {
    condition     = output.name == "test-node"
    error_message = "output.name must echo var.name"
  }

  assert {
    condition     = output.provider_type == "oci"
    error_message = "output.provider_type must echo var.provider_type"
  }

  assert {
    condition     = output.wireguard_ip == "10.200.0.99"
    error_message = "output.wireguard_ip must echo var.wireguard_address"
  }

  assert {
    condition     = output.ssh_via_wireguard == "ssh ubuntu@10.200.0.99"
    error_message = "output.ssh_via_wireguard must be 'ssh <docker_user>@<wireguard_address>'"
  }

  assert {
    condition     = output.nomad_node_class == "cloud"
    error_message = "output.nomad_node_class must echo var.node_class (default 'cloud')"
  }

  assert {
    condition     = output.nomad_node_pool == ""
    error_message = "output.nomad_node_pool must echo var.node_pool (default '')"
  }

  assert {
    condition     = output.datacenter == "dc1"
    error_message = "output.datacenter must echo var.datacenter (default 'dc1')"
  }

  # --- OUTPUT: compute-derived values are wired from the compute sub-module ---
  assert {
    condition     = output.instance_id != null
    error_message = "output.instance_id must be wired from compute sub-module"
  }

  assert {
    condition     = output.public_ip != null
    error_message = "output.public_ip must be wired from compute sub-module"
  }

  assert {
    condition     = output.private_ip != null
    error_message = "output.private_ip must be wired from compute sub-module"
  }

  assert {
    condition     = output.ssh_connection_string != null
    error_message = "output.ssh_connection_string must be wired from compute sub-module"
  }

  # --- OUTPUT: raw compute object passed through ---
  assert {
    condition     = output.compute != null
    error_message = "output.compute must be the raw compute module object"
  }

  # --- OUTPUT: cloud-init script (sensitive) renders to a non-empty string ---
  assert {
    condition     = length(nonsensitive(output.cloud_init_script)) > 0
    error_message = "output.cloud_init_script must render to a non-empty string"
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
