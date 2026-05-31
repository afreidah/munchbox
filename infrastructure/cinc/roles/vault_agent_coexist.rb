# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: vault_agent_coexist
#
# Tells the vault_agent cookbook to share an already-installed vault binary
# (do NOT apt-install + do NOT mask vault.service). Used on nodes that
# already run a full vault server -- chef-managed vault-agent shares the
# existing /usr/local/bin/vault and runs out of a separate config_dir so the
# two systemd units coexist.
# -------------------------------------------------------------------------------

name 'vault_agent_coexist'
description 'vault-agent shares an existing vault binary; do not mask vault.service'

override_attributes(
  vault_agent: {
    binary_path: '/usr/local/bin/vault',
    config_dir: '/etc/vault-agent.d',
    install: {
      install_binary: false,
      mask_vault_service: false,
    },
  },
)
