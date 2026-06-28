#!/usr/bin/env ruby
# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Terraform module test-coverage analyzer (stdlib only -- no gems).
#
# Author: Alex Freidah / Project: Munchbox
#
# Terraform has no line coverage. Instead we measure the meaningful signals by
# cross-referencing each module's *.tf declarations against the HCL references in
# its tests/*.tftest.hcl:
#   resource coverage  - % of `resource "T" "N"` referenced as T.N in a test
#   output coverage    - % of `output "N"` asserted as output.N in a test
#   variable coverage  - % of `variable "N"` set (N =) or referenced (var.N)
#
# Targets: output 100%, resource 90% (variable is advisory). The CI gate is a
# RATCHET: --check fails if any module's uncovered resource/output count grew
# vs the committed baseline, so coverage can only hold or improve. Lock in gains
# with --write-baseline.
#
# Usage:
#   tf-coverage.rb                 # full report table
#   tf-coverage.rb --module DIR    # single-module report (used by `make coverage`)
#   tf-coverage.rb --check         # ratchet gate vs baseline (CI); exit 1 on regression
#   tf-coverage.rb --write-baseline# snapshot current coverage as the new baseline
#   tf-coverage.rb --json          # machine-readable totals (for the badge)
# -------------------------------------------------------------------------------

require 'json'
require 'optparse'

SCRIPT_DIR  = __dir__
MODULES_DIR = File.expand_path('../modules', SCRIPT_DIR)
BASELINE    = File.join(SCRIPT_DIR, 'tf-coverage-baseline.json')
TARGETS     = { 'resource' => 90, 'output' => 100 }.freeze # 'variable' is advisory

RES_RE = /^\s*resource\s+"([^"]+)"\s+"([^"]+)"/
OUT_RE = /^\s*output\s+"([^"]+)"/
VAR_RE = /^\s*variable\s+"([^"]+)"/

# Coverage for one module dir => {"resource"=>[covered,total], "output"=>..., "variable"=>...}
def module_coverage(mod)
  cfg   = Dir.glob(File.join(mod, '*.tf')).map { |f| File.read(f) }.join("\n")
  tests = Dir.glob(File.join(mod, 'tests', '*.tftest.hcl')).map { |f| File.read(f) }.join("\n")
  resources = cfg.scan(RES_RE)
  outputs   = cfg.scan(OUT_RE).flatten
  variables = cfg.scan(VAR_RE).flatten
  {
    'resource' => [resources.count { |t, n| tests.include?("#{t}.#{n}") }, resources.size],
    'output'   => [outputs.count { |n| tests.include?("output.#{n}") }, outputs.size],
    'variable' => [variables.count { |n| tests.include?("var.#{n}") || tests.match?(/^\s*#{Regexp.escape(n)}\s*=/) }, variables.size],
  }
end

def all_modules
  Dir.glob(File.join(MODULES_DIR, '*')).select { |d| File.directory?(d) }.sort
end

def report_all
  all_modules.to_h { |m| [File.basename(m), module_coverage(m)] }
end

def aggregate(data)
  agg = { 'resource' => [0, 0], 'output' => [0, 0], 'variable' => [0, 0] }
  data.each_value { |cov| agg.each_key { |k| agg[k][0] += cov[k][0]; agg[k][1] += cov[k][1] } }
  agg
end

def fmt(cov, tot)
  return '  -  ' if tot.zero?
  format('%d/%d %3d%%', cov, tot, cov * 100 / tot)
end

def below_target?(cov)
  %w[resource output].any? do |k|
    c, t = cov[k]
    !t.zero? && (c * 100 / t) < TARGETS[k]
  end
end

def print_table(data)
  printf("%-28s %-13s %-13s %-13s\n", 'module', 'resource', 'output', 'variable')
  puts '-' * 72
  data.each do |name, cov|
    printf("%-28s %-13s %-13s %-13s %s\n", name,
           fmt(*cov['resource']), fmt(*cov['output']), fmt(*cov['variable']),
           below_target?(cov) ? '<<' : '')
  end
  agg = aggregate(data)
  puts '-' * 72
  printf("%-28s %-13s %-13s %-13s\n", 'TOTAL',
         fmt(*agg['resource']), fmt(*agg['output']), fmt(*agg['variable']))
  agg
end

# Combined badge %: (resource + output) covered / total. Outputs are the contract,
# resources the implementation; variable is advisory so it's excluded.
def badge_pct(agg)
  cov = agg['resource'][0] + agg['output'][0]
  tot = agg['resource'][1] + agg['output'][1]
  tot.zero? ? 100 : cov * 100 / tot
end

opts = {}
OptionParser.new do |o|
  o.on('--module DIR') { |d| opts[:module] = d }
  o.on('--check')          { opts[:check] = true }
  o.on('--write-baseline') { opts[:write] = true }
  o.on('--json')           { opts[:json] = true }
end.parse!

if opts[:module]
  dir = File.expand_path(opts[:module])
  print_table(File.basename(dir) => module_coverage(dir))
  exit 0
end

data = report_all

if opts[:json]
  puts JSON.generate({ combined: badge_pct(aggregate(data)) }.merge(aggregate(data)))
  exit 0
end

if opts[:write]
  File.write(BASELINE, "#{JSON.pretty_generate(data)}\n")
  puts "wrote baseline: #{BASELINE}"
  exit 0
end

if opts[:check]
  baseline = File.exist?(BASELINE) ? JSON.parse(File.read(BASELINE)) : {}
  regressions = []
  data.each do |name, cov|
    base = baseline[name]
    %w[resource output].each do |k|
      cur  = cov[k][1] - cov[k][0]
      prev = base ? base[k][1] - base[k][0] : cur
      regressions << "#{name} #{k}: uncovered #{prev} -> #{cur}" if cur > prev
    end
  end
  print_table(data)
  puts "\ncombined coverage: #{badge_pct(aggregate(data))}%"
  if regressions.empty?
    puts 'ratchet OK (no resource/output coverage regression vs baseline)'
    exit 0
  end
  puts "\nCOVERAGE REGRESSION (cover the new resources/outputs, or run --write-baseline if intentional):"
  regressions.each { |r| puts "  #{r}" }
  exit 1
end

print_table(data)
