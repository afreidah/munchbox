# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Recipe:: register
#
# Registers cinc-server with the local consul agent so it resolves at
# cinc-server.service.consul and surfaces a green health check in the UI.
# Requires the node to also run role[consul_client] (recipe will no-op
# at converge if consul isn't installed yet -- the file lands but the
# reload notification can't fire).
# -------------------------------------------------------------------------------

consul_service 'cinc-server' do
  port 443
  tags %w(chef cinc https)
  # --- tls_skip_verify: cinc-server's nginx cert is self-signed by cinc_server::configure (openssl_x509_certificate). Flip to false when the cert moves to munchbox PKI. ---
  check(
    'name' => 'cinc-server https /_status',
    'http' => 'https://cinc-server.munchbox.cc/_status',
    'method' => 'GET',
    'interval' => '30s',
    'timeout' => '5s',
    'tls_skip_verify' => true
  )
end
