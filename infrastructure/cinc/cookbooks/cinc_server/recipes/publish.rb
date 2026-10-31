# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Recipe:: publish
#
# Publishes the server's webui keypair to Vault for cinc-console, which signs
# requests with the private half. The server generates the pair at install
# and has no supported way to take a supplied one, so the server is the source
# and Vault holds the copy.
# -------------------------------------------------------------------------------

webui = node[cookbook]['publish']['webui']

cinc_server_vault_publish webui['vault_path'] do
  files webui['files'].to_hash
end
