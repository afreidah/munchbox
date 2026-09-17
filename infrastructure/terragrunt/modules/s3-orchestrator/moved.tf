# -----------------------------------------------------------------------------
# S3-ORCHESTRATOR GRANT STATE MIGRATION
# -----------------------------------------------------------------------------
#
# Grants were keyed by identity while an identity held exactly one. They are now
# keyed by identity, kind and name, because an identity can hold several.
#
# Both keys address the same grant: the orchestrator identifies one by user,
# kind and name, none of which changed. Without these blocks Terraform reads the
# rekey as five instances leaving the map and five arriving, and nothing orders
# the destroy of an old key against the create of a new one -- a create that
# lands first upserts the grant and the destroy then removes it, leaving the
# client reaching nothing.
#
# These can be deleted once every deployment of this module has applied them.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

moved {
  from = s3orchestrator_grant.this["temporal-backups-worker"]
  to   = s3orchestrator_grant.this["temporal-backups-worker/bucket/unified"]
}

moved {
  from = s3orchestrator_grant.this["aptly"]
  to   = s3orchestrator_grant.this["aptly/bucket/aptly"]
}

moved {
  from = s3orchestrator_grant.this["tempo"]
  to   = s3orchestrator_grant.this["tempo/bucket/tempo-traces"]
}

moved {
  from = s3orchestrator_grant.this["artifacts_s3o_writer"]
  to   = s3orchestrator_grant.this["artifacts_s3o_writer/bucket/artifacts"]
}

moved {
  from = s3orchestrator_grant.this["artifacts_terragrunt_reader"]
  to   = s3orchestrator_grant.this["artifacts_terragrunt_reader/bucket/artifacts"]
}
