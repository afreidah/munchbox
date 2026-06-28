# frozen_string_literal: true
require_relative '../../simplecov_bootstrap'

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Spec helper.
# -------------------------------------------------------------------------------

require 'chefspec'

# --- Load vault_fetch lib so MunchboxLibVaultFetch exists for the stub below ---
require File.expand_path('../../munchbox_lib/libraries/vault_fetch.rb', __dir__)

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! { add_filter 'munchbox_lib' }

# --- Stub vault_fetch via module monkey-patch (only reliable way for lazy{}). ---
RSpec.configure do |c|
  c.before(:each) do
    MunchboxLibVaultFetch.module_eval do
      define_method(:vault_fetch) { |_path, _field| 'fake-vault-value' }
    end
  end
end

RSpec.configure do |config|
  config.cookbook_path = [File.expand_path('../../', __dir__)]
  config.platform        = 'debian'
  config.version         = '12'
  config.log_level       = :error
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end
