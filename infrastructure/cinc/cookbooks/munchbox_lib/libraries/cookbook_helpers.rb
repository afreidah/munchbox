# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Library:: cookbook_helpers
#
# Shared helpers loaded by every cookbook that `depends 'munchbox_lib'`.
#
# The headline helper is `cookbook`, which derives the calling cookbook's name
# from its `metadata.rb` so the literal cookbook name only appears in one
# place per cookbook. Made available both as `MunchboxLibCookbook::Helpers
# .cookbook` and as a bare `cookbook` method inside recipes and resources
# (via the DSL extension at the bottom of this file).
#
# Caveat: chef evaluates attribute files before libraries, so this helper is
# NOT available in `attributes/*.rb`. Attribute files need to declare a local
# `cookbook = '<name>'` at the top, matching `metadata.rb` by hand. Every
# other context (recipes, resources, templates) gets it for free.
# -------------------------------------------------------------------------------

module MunchboxLibCookbook
  module Helpers
    # -----------------------------------------------------------------------------
    # Two-level cache for cookbook name lookups.
    #
    #   @by_caller[path] -> cookbook name, keyed by the calling .rb file.
    #                       Skips the directory walk on repeat calls.
    #   @by_root[root]   -> cookbook name, keyed by absolute cookbook root.
    #                       Skips re-parsing metadata.rb across files in
    #                       the same cookbook.
    #
    # Both live for the chef-client process lifetime, no need to invalidate.
    # -----------------------------------------------------------------------------

    @by_caller = {}
    @by_root   = {}

    class << self
      # --- Return the cookbook name from the caller's metadata.rb ---
      def cookbook(from = caller_locations(1, 1).first.path)
        @by_caller[from] ||= begin
          root = find_cookbook_root(File.expand_path(from))
          @by_root[root] ||= parse_metadata_name(File.join(root, 'metadata.rb'))
        end
      end

      # --- Test-only escape hatch; production runs never need this ---
      def reset_cache!
        @by_caller = {}
        @by_root   = {}
      end

      private

      # --- Walk upward from `start` until a metadata.rb is found ---
      def find_cookbook_root(start)
        dir = File.dirname(start)
        loop do
          return dir if File.exist?(File.join(dir, 'metadata.rb'))
          parent = File.dirname(dir)
          raise "munchbox_lib: no metadata.rb found above #{start}" if parent == dir
          dir = parent
        end
      end

      # --- Scan metadata.rb for the `name '...'` directive ---
      def parse_metadata_name(path)
        File.foreach(path) do |line|
          m = line.match(/^\s*name\s+['"]([^'"]+)['"]/)
          return m[1] if m
        end
        raise "munchbox_lib: no `name` directive in #{path}"
      end
    end
  end
end

# -------------------------------------------------------------------------------
# DSL extension
#
# Make `cookbook` available as a bare method inside recipes and resources.
# Wrapping it in a module so we pass the *caller's* file path through;
# otherwise the default would always resolve to this file.
# -------------------------------------------------------------------------------

dsl_extension = Module.new do
  # --- Bare DSL method; delegates to the cached module helper ---
  def cookbook
    MunchboxLibCookbook::Helpers.cookbook(caller_locations(1, 1).first.path)
  end
end

Chef::DSL::Recipe.include(dsl_extension)
Chef::Resource.include(dsl_extension)
