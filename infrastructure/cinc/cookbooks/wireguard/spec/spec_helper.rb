# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Spec helper
# -------------------------------------------------------------------------------

require 'chefspec'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

ChefSpec::Coverage.start! { add_filter 'munchbox_lib' }

RSpec.configure do |config|
  config.cookbook_path = [
    File.expand_path('../../', __dir__),
    File.expand_path('../../../munchbox_lib', __dir__),
  ]

  config.platform        = 'ubuntu'
  config.version         = '24.04'
  config.log_level       = :error
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)
end
