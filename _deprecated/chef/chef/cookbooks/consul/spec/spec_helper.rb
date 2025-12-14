# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Consul Cookbook - Spec Helper
#
# Project: Munchbox / Author: Alex Freidah
#
# ChefSpec configuration for Consul cookbook testing. Loads ChefSpec, sets up
# coverage, and configures RSpec for cookbook testing.
# -------------------------------------------------------------------------------

require 'chefspec'
require 'chefspec/berkshelf'

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

# --- ChefSpec runner configuration ---
# Ensures ChefSpec can find this cookbook and its dependencies.

RSpec.configure do |config|
  config.cookbook_path = [
    File.expand_path('../', __dir__), # <project_root>
    File.expand_path('cookbooks', File.expand_path('../', __dir__)), # <project_root>/cookbooks
    File.expand_path('cookbooks', __dir__), # <project_root>/spec/cookbooks
  ]
  config.color = true
  config.formatter = :documentation
end

# --- ChefSpec coverage ---
ChefSpec::Coverage.start!
