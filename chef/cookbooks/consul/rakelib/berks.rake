# frozen_string_literal: true

# ----------------------------------------------------------------------------
# Berkshelf Tasks
# ----------------------------------------------------------------------------
namespace :berks do
  # --- Install: Installs cookbook dependencies using Berkshelf ---
  desc 'Install cookbook dependencies using Berkshelf. Usage: rake berks:install'
  task :install do
    sh 'berks install'
  end
  Rake::Task['berks:install'].comment = 'Install cookbook dependencies using Berkshelf. Usage: rake berks:install'

  # --- Vendor: Vendors cookbooks using Berkshelf ---
  desc 'Vendor cookbooks using Berkshelf. Usage: rake berks:vendor'
  task :vendor do
    sh 'berks vendor berks-cookbooks'
  end
  Rake::Task['berks:vendor'].comment = 'Vendor cookbooks using Berkshelf. Usage: rake berks:vendor'

  # --- Update: Updates cookbook dependencies using Berkshelf ---
  desc 'Update cookbook dependencies using Berkshelf. Usage: rake berks:update'
  task :update do
    sh 'berks update'
  end
  Rake::Task['berks:update'].comment = 'Update cookbook dependencies using Berkshelf. Usage: rake berks:update'

  # --- Fresh: Cleans all berkshelf stuff and reinstalls/vendor cookbooks ---
  desc 'Clean all berkshelf stuff and re-intall and vendor cookbooks'
  task :fresh do
    sh 'rm -rf Berkshelf.lock berks-cookbooks; berks install; berks vendor berks-cookbooks'
  end
  Rake::Task['berks:fresh'].comment = 'remove and reinstall vendor cookbook dependencies. Usage: rake berks:fresh'
end
