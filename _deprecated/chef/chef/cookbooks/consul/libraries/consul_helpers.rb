# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  Library: consul_helpers.rb — Helper methods for Consul installation
#
#  Provides architecture mapping and archive URL construction for Consul
#  binary installation.
# ------------------------------------------------------------------------------

module ConsulCookbook
  # --- Map kernel machine to HashiCorp archive label ---
  def self.archive_arch(machine)
    case machine
    when 'x86_64' then 'linux_amd64'
    when 'aarch64', 'arm64' then 'linux_arm64'
    else 'linux_amd64'
    end
  end

  # --- Build Consul archive download URL ---
  def self.archive_url(version, arch)
    "https://releases.hashicorp.com/consul/#{version}/consul_#{version}_#{arch}.zip"
  end
end
