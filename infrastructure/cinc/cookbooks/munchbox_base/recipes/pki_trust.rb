# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: pki_trust
#
# Installs Munchbox PKI root + intermediate CAs into the system trust
# store so any TLS client on the node (chef itself, vault-agent, curl,
# downstream cookbooks talking to internal HTTPS) trusts internally
# issued certs without per-tool ca_cert plumbing.
# -------------------------------------------------------------------------------

munchbox_base_pki_trust 'munchbox-pki'
