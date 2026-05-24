# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: vault_agent
#
# Installs Vault Agent and brings it up under AppRole auto-auth. After the
# run, vault-agent maintains a current Vault token at /run/vault-agent/token
# for downstream cookbooks to read via `secret(service: :hashi_vault, ...)`.
#
# AppRole role_id (shared) + secret_id (per-node) live in the encrypted
# data bag `vault_agent/<node.name>`. Provision before first converge:
#   knife data bag create vault_agent --secret-file <secret>
#   knife data bag from file vault_agent <node>.json --secret-file <secret>
# -------------------------------------------------------------------------------

name 'vault_agent'
description 'Installs Vault Agent + AppRole auto-auth; produces /run/vault-agent/token'

run_list(
  'recipe[vault_agent::install]',
  'recipe[vault_agent::configure]'
)
