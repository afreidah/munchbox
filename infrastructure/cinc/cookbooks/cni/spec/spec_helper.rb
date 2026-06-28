# frozen_string_literal: true
require_relative '../../simplecov_bootstrap'

# -------------------------------------------------------------------------------
# Cookbook:: cni
# Spec helper.
# -------------------------------------------------------------------------------

require 'chefspec'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! { add_filter 'munchbox_lib' }

RSpec.configure do |config|
  config.cookbook_path = [File.expand_path('../../', __dir__)]
  config.platform        = 'debian'
  config.version         = '12'
  config.log_level       = :error
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end
