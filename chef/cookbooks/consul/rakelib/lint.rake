# frozen_string_literal: true

# ----------------------------------------------------------------------------
# Linting tasks: Run Cookstyle for linting and auto-correction
# ----------------------------------------------------------------------------

namespace :lint do
  # --- Lint: Runs Cookstyle for linting ---
  desc 'Run Cookstyle for linting. Usage: rake lint:cookstyle'
  task :cookstyle do
    sh 'bundle exec cookstyle'
  end
  Rake::Task['lint:cookstyle'].comment = 'Run Cookstyle for linting. Usage: rake lint:cookstyle'

  # --- Lint Fix: Runs Cookstyle with auto-correction ---
  desc 'Run Cookstyle to fix issues. Usage: rake lint:cookstyle_fix'
  task :fix do
    sh 'bundle exec cookstyle -a'
  end
  Rake::Task['lint:fix'].comment = 'Run Cookstyle to fix issues. Usage: rake lint:cookstyle_fix'

  # --- Lint Fix Unsafe: Runs Cookstyle with unsafe auto-correction ---
  desc 'Run Cookstyle to fix issues unsafe. Usage: rake lint:cookstyle_fix_unsafe'
  task :fix_unsafe do
    sh 'bundle exec cookstyle -A'
  end
  Rake::Task['lint:fix_unsafe'].comment = 'Run Cookstyle to fix issues unsafe. Usage: rake lint:cookstyle_fix_unsafe'
end

# --- Set default spec task ---
task lint: 'lint:cookstyle'
