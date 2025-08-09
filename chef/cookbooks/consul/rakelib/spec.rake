# frozen_string_literal: true

# ----------------------------------------------------------------------------
# ChefSpec/RSpec Tasks
# ----------------------------------------------------------------------------

namespace :spec do
  # --- ChefSpec: Runs all ChefSpec (RSpec) unit specs with environment variables ---
  desc 'Run all ChefSpec (RSpec) unit specs with environment variables. Usage: rake test:chefspec[formatter]'
  task :chefspec, [:formatter] do |_t, args|
    formatter = args[:formatter] || ENV['FORMATTER'] || 'documentation'
    ENV['CHEF_NODE_NAME'] = 'chefspec-spec'
    ENV['TEST_KITCHEN'] = '1'
    cmd = 'bundle exec rspec spec'
    cmd += " --format #{formatter}" if formatter
    sh cmd
  end

  Rake::Task['spec:chefspec'].comment = 'Run all ChefSpec (RSpec) unit tests with environment variables. Usage: rake test:chefspec'
end

# --- Set default spec task ---
task spec: 'spec:chefspec'
