# frozen_string_literal: true
require_relative '../../simplecov_bootstrap'

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Spec helper
# -------------------------------------------------------------------------------

require 'chefspec'

# --- Load pinned_version (defines MunchboxLibPinnedVersion) before the stub below ---
require File.expand_path('../../munchbox_lib/libraries/pinned_version.rb', __dir__)

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! { add_filter 'munchbox_lib' }

# --- Stub the data-bag version lookup; module monkey-patch is the only reliable
#     way (allow_any_instance_of misses calls on resource properties).
RSpec.configure do |c|
  c.before(:each) do
    MunchboxLibPinnedVersion.module_eval do
      define_method(:pinned_version) { |_tool| '2.0.3' }
    end
  end
end

RSpec.configure do |config|
  config.cookbook_path = [
    File.expand_path('../../', __dir__),
    File.expand_path('../../../munchbox_lib', __dir__),
    File.expand_path('../../../munchbox_base', __dir__),
  ]

  config.platform        = 'debian'
  config.version         = '12'
  config.log_level       = :error
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end
