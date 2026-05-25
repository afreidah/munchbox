# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault
# Spec helper.
# -------------------------------------------------------------------------------

require 'chefspec'

# Load munchbox_lib's vault_fetch (defines MunchboxLibVaultFetch) before any
# spec runs so the per-spec stubs below can override its method directly.
require File.expand_path('../../munchbox_lib/libraries/vault_fetch.rb', __dir__)

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! { add_filter 'munchbox_lib' }

# --- Stub vault_fetch globally; modules can't be allow_any_instance_of'd, so
#     we redefine the method on the module itself per example. Individual specs
#     can override with their own module_eval to test alternate return values.
RSpec.configure do |c|
  c.before(:each) do
    MunchboxLibVaultFetch.module_eval do
      define_method(:vault_fetch) { |_path, _field| 'fake-vault-value' }
    end
  end
end

RSpec.configure do |config|
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
