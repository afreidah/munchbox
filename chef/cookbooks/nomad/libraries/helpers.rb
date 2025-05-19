# frozen_string_literal: true
#
# Cookbook:: nomad
# Library:: helpers
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Provides helper methods for Nomad-related operations.
#

module Nomad
  module Helpers
    # Returns the installed Nomad version as a string (e.g., "v1.5.3").
    #
    # @return [String, nil] The Nomad version, or nil if not found.
    def nomad_version
      cmd = Mixlib::ShellOut.new('/usr/local/bin/nomad version')
      cmd.run_command
      cmd.stdout.lines.first.to_s.split[1]
    end
  end
end

Chef::Recipe.include(Nomad::Helpers)
Chef::Resource.include(Nomad::Helpers)
Chef::Provider.include(Nomad::Helpers) if defined?(Chef::Provider)
