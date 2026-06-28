# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Shared SimpleCov bootstrap for cookbook specs.
#
# require_relative'd at the TOP of every cookbook's spec/spec_helper.rb (before
# any cookbook code loads) so line coverage is tracked. Inert unless COVERAGE=1,
# so local `chef exec rspec` / `bundle exec rspec` runs don't need SimpleCov
# installed and behave exactly as before. CI sets COVERAGE=1 and installs
# simplecov + simplecov-cobertura.
#
# Each cookbook runs in its own process (per-cookbook `make test`), so we give
# each a distinct command_name and a shared coverage_dir; SimpleCov merges the
# per-cookbook resultsets into one cinc/coverage/coverage.xml for SonarCloud.
# -------------------------------------------------------------------------------

return unless ENV['COVERAGE'] == '1'

require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  # Consistent root across every per-cookbook process. Each process formats the
  # merged result against SimpleCov.root, so without a fixed root the last
  # cookbook's dir wins and the report drops every other cookbook's files.
  root File.expand_path('..', __dir__) # cookbooks/ -> infrastructure/cinc
  command_name "cinc-#{File.basename(Dir.pwd)}"
  coverage_dir File.expand_path('../coverage', __dir__) # -> infrastructure/cinc/coverage
  formatter SimpleCov::Formatter::CoberturaFormatter
  enable_coverage :branch
  merge_timeout 3600
  # ChefSpec instance_eval's recipes/resources/attributes, so Ruby's Coverage
  # can't attribute lines to them -- only require'd libraries are measurable.
  add_filter %r{/spec/}
  add_filter %r{/test/}
end
