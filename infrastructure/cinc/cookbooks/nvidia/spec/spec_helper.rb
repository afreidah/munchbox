# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nvidia
# Spec helper.
# -------------------------------------------------------------------------------

require 'chefspec'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! do
  add_filter 'munchbox_lib'
  add_filter 'munchbox_base'
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
