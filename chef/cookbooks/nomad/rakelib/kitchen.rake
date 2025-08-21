# frozen_string_literal: true

# ----------------------------------------------------------------------------
# Kitchen Tasks
# ----------------------------------------------------------------------------
# Usage:
#   bundle exec rake kitchen:converge[instance_name]
#   bundle exec rake kitchen:verify[instance_name]
#   bundle exec rake kitchen:destroy[instance_name]
#   bundle exec rake kitchen:test[instance_name]
#
#   Or set INSTANCE environment variable:
#     INSTANCE=instance_name bundle exec rake kitchen:converge
# ----------------------------------------------------------------------------

namespace :kitchen do
  # --- Converge: Vendors cookbooks and runs kitchen converge on an instance ---
  desc 'Run kitchen converge (auto-vendor cookbooks first). Usage: rake kitchen:converge[instance] or INSTANCE=instance rake kitchen:converge'
  task :converge, [:instance] do |_t, args|
    Rake::Task['berks:fresh'].invoke
    instance = args[:instance] || ENV['INSTANCE']
    sh "kitchen converge#{' ' + instance if instance}"
  end
  Rake::Task['kitchen:converge'].comment = 'Run kitchen converge (auto-vendor cookbooks first). Usage: rake kitchen:converge[instance] or INSTANCE=instance rake kitchen:converge'

  # --- Verify: Runs kitchen verify on an instance ---
  desc 'Run kitchen verify. Usage: rake kitchen:verify[instance] or INSTANCE=instance rake kitchen:verify'
  task :verify, [:instance] do |_t, args|
    instance = args[:instance] || ENV['INSTANCE']
    sh "kitchen verify#{' ' + instance if instance}"
  end
  Rake::Task['kitchen:verify'].comment = 'Run kitchen verify. Usage: rake kitchen:verify[instance] or INSTANCE=instance rake kitchen:verify'

  # --- Destroy: Destroys the kitchen instance ---
  desc 'Run kitchen destroy. Usage: rake kitchen:destroy[instance] or INSTANCE=instance rake kitchen:destroy'
  task :destroy, [:instance] do |_t, args|
    instance = args[:instance] || ENV['INSTANCE']
    sh "kitchen destroy#{' ' + instance if instance}"
  end
  Rake::Task['kitchen:destroy'].comment = 'Run kitchen destroy. Usage: rake kitchen:destroy[instance] or INSTANCE=instance rake kitchen:destroy'

  # --- Login: SSH into the kitchen instance ---
  desc 'Run kitchen login. Usage: rake kitchen:login[instance] or INSTANCE=instance rake kitchen:login'
  task :login, [:instance] do |_t, args|
    instance = args[:instance] || ENV['INSTANCE']
    sh "kitchen login#{' ' + instance if instance}"
  end
  Rake::Task['kitchen:login'].comment = 'Run kitchen login. Usage: rake kitchen:login[instance] or INSTANCE=instance rake kitchen:login'

  # --- Test: Runs kitchen test on an instance ---
  desc 'Run kitchen test. Usage: rake kitchen:test[instance] or INSTANCE=instance rake kitchen:test'
  task :test, [:instance] do |_t, args|
    instance = args[:instance] || ENV['INSTANCE']
    sh "kitchen test#{' ' + instance if instance}"
  end
  Rake::Task['kitchen:test'].comment = 'Run kitchen test. Usage: rake kitchen:test[instance] or INSTANCE=instance rake kitchen:test'
end

# --- Set high level inspec task ---
task :inspec, [:instance] => [:verify] do |_t, args|
  Rake::Task[:verify].invoke(args[:instance])
end
