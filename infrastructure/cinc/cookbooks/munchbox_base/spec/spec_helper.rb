# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Spec helper -- wires up chefspec with our cookbook path so the `cookbook`
# helper from munchbox_lib resolves correctly when recipes and resources run.
# -------------------------------------------------------------------------------

require 'chefspec'

# --- Load shared rspec/chefspec matchers (e.g. do_nothing) ---
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! { add_filter 'munchbox_lib' }

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
