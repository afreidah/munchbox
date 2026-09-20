# -----------------------------------------------------------------------------
# CODE-ENGINE MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates a Code Engine project per map entry, each with its own Service ID and
# an API key scoped to that project alone. Generic: it knows nothing about what
# runs there, so one catalog entry is all a new consumer needs.
#
# Vault-free, matching access-keys: the API keys are sensitive outputs that the
# vault-secrets leaf writes. A module that both mints and stores a credential
# makes the store a dependency of every plan that touches the mint.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------

data "ibm_resource_group" "this" {
  for_each = var.projects

  name = each.value.resource_group
}

# -----------------------------------------------------------------------------
# PROJECT
#
# The namespace job runs live in. Regional, and free to hold: Code Engine bills
# for running instances, so an idle project costs nothing.
# -----------------------------------------------------------------------------

resource "ibm_code_engine_project" "this" {
  for_each = var.projects

  name              = each.key
  resource_group_id = data.ibm_resource_group.this[each.key].id
}

# -----------------------------------------------------------------------------
# SERVICE IDENTITY
#
# A non-human identity per project rather than a personal API key. A personal
# key carries every permission its owner has, so a compromised consumer could
# reach the whole account; this one can submit job runs in one project.
# -----------------------------------------------------------------------------

resource "ibm_iam_service_id" "this" {
  for_each = var.projects

  name        = "${each.key}-code-engine"
  description = "Submits Code Engine job runs in the ${each.key} project"
  tags        = [for k, v in each.value.tags : "${k}:${v}"]
}

# -----------------------------------------------------------------------------
# ACCESS POLICY
#
# Writer rather than Manager: creating, reading and deleting job runs is the
# whole job. Manager additionally allows changing the project's own
# configuration, which nothing consuming this needs.
#
# Scoped to the single project instance, so the identity cannot see a second
# project created later in the same account.
# -----------------------------------------------------------------------------

resource "ibm_iam_service_policy" "this" {
  for_each = var.projects

  iam_service_id = ibm_iam_service_id.this[each.key].id
  roles          = each.value.roles

  resources {
    service              = "codeengine"
    resource_group_id    = data.ibm_resource_group.this[each.key].id
    resource_instance_id = element(split(":", ibm_code_engine_project.this[each.key].crn), 7)
  }
}

# -----------------------------------------------------------------------------
# API KEY
#
# Exchanged at runtime for a short-lived IAM bearer token, so this value is the
# only long-lived secret and the one thing worth storing.
# -----------------------------------------------------------------------------

resource "ibm_iam_service_api_key" "this" {
  for_each = var.projects

  name           = "${each.key}-code-engine"
  iam_service_id = ibm_iam_service_id.this[each.key].iam_id
  description    = "Runtime credential for the ${each.key} Code Engine project"
}
