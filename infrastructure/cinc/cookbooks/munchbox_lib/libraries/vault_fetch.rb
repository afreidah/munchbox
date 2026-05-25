# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Library:: vault_fetch
#
# `vault_fetch(path, field)` -- one-liner for reading a KV v2 secret out of
# Vault using the token that vault-agent maintains at /run/vault-agent/token.
# Any cookbook that `depends 'munchbox_lib'` gets the helper inside recipes,
# resources, and action_class blocks (Chef::DSL::Recipe + Chef::Resource
# are extended below).
#
# Defaults:
#   VAULT_TOKEN_SINK   -- /run/vault-agent/token (the standard sink path).
#   VAULT_ADDR_DEFAULT -- https://goren.munchbox.cc:8200 (current Vault cert
#                        SANs don't yet cover the vault.munchbox.cc VIP).
#
# TLS trust comes from the system bundle that `munchbox_base::pki_trust`
# installs (the Munchbox root + intermediate land in
# /etc/ssl/certs/ca-certificates.crt), so callers don't pass ca_cert here.
#
# KV v2 wrapping ({ data: { ...fields... }, metadata: {...} }) is unwrapped
# transparently; the field lookup also tolerates either string or symbol keys.
# -------------------------------------------------------------------------------

module MunchboxLibVaultFetch
  # --- System bundle that munchbox_base::pki_trust populates (root + intermediate via update-ca-certificates) and vault vars ---
  VAULT_TOKEN_SINK   = '/run/vault-agent/token'
  VAULT_ADDR_DEFAULT = 'https://goren.munchbox.cc:8200'
  VAULT_CA_CERT = '/etc/ssl/certs/ca-certificates.crt'

  # --- Wait window for the token sink to appear/reappear  ---
  VAULT_TOKEN_WAIT_SECONDS = 30
  VAULT_TOKEN_WAIT_INTERVAL = 0.5

  # --- Read field `field` at KV v2 path `path`; raises if sink, secret, or field are missing ---
  def vault_fetch(path, field)
    wait_for_token_sink

    token = ::File.read(VAULT_TOKEN_SINK).strip

    # --- chef's SecretFetcher::HashiVault only forwards `address` + `token` to the Vault singleton; set ssl_ca_cert on the module directly ---
    require 'vault'
    Vault.ssl_ca_cert = VAULT_CA_CERT

    raw = secret(
      name: path,
      service: :hashi_vault,
      config: {
        auth_method: :token,
        vault_addr: ENV['VAULT_ADDR'] || VAULT_ADDR_DEFAULT,
        token:,
      }
    )

    # --- KV v2 responses come back as a real symbol-keyed Hash from chef's SecretFetcher::HashiVault: { data: { ...actual fields... }, metadata: {...} } ---
    payload = raw.is_a?(Hash) && raw[:data].is_a?(Hash) ? raw[:data] : raw
    value = payload.is_a?(Hash) ? (payload[field] || payload[field.to_sym]) : nil
    raise "vault: no field '#{field}' at #{path}; available: #{payload.respond_to?(:keys) ? payload.keys.inspect : payload.class}" unless value

    value
  end

  # --- Read the CA certificate from a Vault PKI mount (default `pki_int`). Returns PEM-encoded cert. ---
  def vault_pki_ca(mount = 'pki_int')
    vault_pki_cert(mount, 'ca')
  end

  # --- Read the full CA chain (intermediate + root, concatenated PEM) from a Vault PKI mount. ---
  def vault_pki_ca_chain(mount = 'pki_int')
    vault_pki_cert(mount, 'ca_chain')
  end

  # --- Internal: read a cert/* path from a Vault PKI mount. ---
  def vault_pki_cert(mount, leaf)
    wait_for_token_sink
    token = ::File.read(VAULT_TOKEN_SINK).strip
    require 'vault'
    Vault.ssl_ca_cert = VAULT_CA_CERT
    Vault.address     = ENV['VAULT_ADDR'] || VAULT_ADDR_DEFAULT
    Vault.token       = token
    result = Vault.logical.read("#{mount}/cert/#{leaf}")
    raise "vault: no certificate at #{mount}/cert/#{leaf}" unless result&.data&.dig(:certificate)

    result.data[:certificate]
  end

  # --- Block until /run/vault-agent/token exists (or timeout). Tolerates the brief gap during vault-agent restarts when systemd has wiped RuntimeDirectory but the daemon hasn't yet rewritten the sink. ---
  def wait_for_token_sink
    deadline = ::Time.now + VAULT_TOKEN_WAIT_SECONDS
    loop do
      return if ::File.exist?(VAULT_TOKEN_SINK)
      break if ::Time.now >= deadline

      sleep VAULT_TOKEN_WAIT_INTERVAL
    end
    raise "vault token sink #{VAULT_TOKEN_SINK} not present after #{VAULT_TOKEN_WAIT_SECONDS}s; is vault-agent running on this node?"
  end
end

# -------------------------------------------------------------------------------
# DSL extension -- expose vault_fetch inside recipes, resources, and action_class blocks
# -------------------------------------------------------------------------------

Chef::DSL::Recipe.include(MunchboxLibVaultFetch)
Chef::Resource.include(MunchboxLibVaultFetch)
