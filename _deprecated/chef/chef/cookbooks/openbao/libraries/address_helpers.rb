# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  libraries/address_helpers.rb — OpenBao Cluster Management Library
# ------------------------------------------------------------------------------

module OpenBao
  DEFAULT_PORT = 8200

  # -----------------------------------------------------------------------------
  # Address helpers
  # -----------------------------------------------------------------------------

  module AddressHelpers
    # --- This node's steady-state address (FQDN + port) ---
    def this_node_addr
      fqdn = shell_out('hostname -f').stdout.strip
      "https://#{fqdn}:#{DEFAULT_PORT}"
    end

    # --- Local probe address (loopback + port) ---
    def local_probe_addr
      "https://127.0.0.1:#{DEFAULT_PORT}"
    end

    # --- Primary IP address of this node ---
    def primary_ip
      ip = begin
             shell_out('hostname -I').stdout.split.first
           rescue
             nil
           end
      return ip if ip.to_s != ''
      shell_out("ip -o route get 1.1.1.1 | awk '{print $7; exit}'").stdout.strip
    end
  end
end
