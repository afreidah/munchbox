# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  spec_helper.rb — ChefSpec Configuration for Consul Cookbook
#  Loads ChefSpec, sets up coverage, and configures RSpec for cookbook testing.
# ------------------------------------------------------------------------------

require 'chefspec'
require 'chefspec/berkshelf'

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

# ------------------------------------------------------------------------------
#  ChefSpec Runner Configuration
# ------------------------------------------------------------------------------
#  Ensures ChefSpec can find this cookbook and its dependencies.
# ------------------------------------------------------------------------------

RSpec.configure do |config|
  config.cookbook_path = [
    File.expand_path('../', __dir__), # <project_root>
    File.expand_path('cookbooks', File.expand_path('../', __dir__)), # <project_root>/cookbooks
    File.expand_path('cookbooks', __dir__), # <project_root>/spec/cookbooks
  ]
  config.color = true
  config.formatter = :documentation
end

# ------------------------------------------------------------------------------
#  ChefSpec Coverage
# ------------------------------------------------------------------------------

ChefSpec::Coverage.start!
