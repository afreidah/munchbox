# frozen_string_literal: true
require_relative '../../simplecov_bootstrap'

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Spec helper -- wires up chefspec with our cookbook path so the `cookbook`
# helper from munchbox_lib resolves correctly when recipes and resources run.
# -------------------------------------------------------------------------------

require 'chefspec'

# --- Load vault_fetch lib so MunchboxLibVaultFetch exists for the stub below ---
require File.expand_path('../../munchbox_lib/libraries/vault_fetch.rb', __dir__)

# --- Load shared rspec/chefspec matchers (e.g. do_nothing) ---
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! { add_filter 'munchbox_lib' }

# --- Stub the MunchboxLibVaultFetch helpers via module monkey-patch.
#     allow_any_instance_of misses lazy-block calls; vault_pki_trust /
#     sshd_ca would otherwise hang in wait_for_token_sink. ---
RSpec.configure do |c|
  c.before(:each) do
    MunchboxLibVaultFetch.module_eval do
      define_method(:vault_fetch)        { |_path, _field| 'fake-vault-value' }
      define_method(:vault_pki_ca)       { |_mount = 'pki_int'| "-----BEGIN CERTIFICATE-----\nfake-ca\n-----END CERTIFICATE-----\n" }
      define_method(:vault_pki_ca_chain) { |_mount = 'pki_int'| "-----BEGIN CERTIFICATE-----\nfake-chain\n-----END CERTIFICATE-----\n" }
    end
  end
end

RSpec.configure do |config|
  # --- Point chefspec at this cookbook + munchbox_lib next door ---
  config.cookbook_path = [
    File.expand_path('../../', __dir__),
    File.expand_path('../../../munchbox_lib', __dir__),
  ]

  config.platform        = 'debian'
  config.version         = '12'
  config.log_level       = :error
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end
