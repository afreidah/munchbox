# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Spec helper
#
# Stubs out the Chef DSL constants so the library file loads under plain
# rspec without dragging in the full chef gem stack. The cookbook_helpers
# library calls `Chef::DSL::Recipe.include(...)` and `Chef::Resource
# .include(...)` at load time; we give it empty stand-ins.
# -------------------------------------------------------------------------------

module Chef; end unless defined?(Chef)
module Chef::DSL; end unless defined?(Chef::DSL)
module Chef::DSL::Recipe; end unless defined?(Chef::DSL::Recipe)
class Chef::Resource; end unless defined?(Chef::Resource)

require_relative '../libraries/cookbook_helpers'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)

  # --- Reset the helper's caches between examples for isolation ---
  config.before(:each) { MunchboxLibCookbook::Helpers.reset_cache! }
end
