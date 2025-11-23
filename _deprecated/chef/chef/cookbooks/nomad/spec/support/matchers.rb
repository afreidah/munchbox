# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  matchers.rb — ChefSpec Custom Matchers for Nomad Cookbook
#  Defines ChefSpec matchers for custom resources in this cookbook.
# ------------------------------------------------------------------------------

if defined?(ChefSpec)
  ChefSpec.define_matcher :nomad_cluster

  def converge_nomad_cluster(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:nomad_cluster, :converge, resource_name)
  end
end
