# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: cinc_server_host
#
# The cinc/chef server itself. Composes role[base] (OS baseline) +
# cinc_server::* (the server itself) + role[cinc_client] (so the host is
# chef-managed like every other node). Server-managed-by-itself loop.
# Also runs a local consul agent + registers itself in the catalog so
# cinc-server.service.consul resolves cluster-wide.
# -------------------------------------------------------------------------------

name 'cinc_server_host'
description 'The cinc/chef server itself; runs base + cinc_server::* + cinc_client + consul-client + self-register'

run_list(
  'role[base]',
  'role[cinc_client]',
  # --- qemu-guest-agent; gives the hypervisor graceful shutdown, guest IP reporting, and fs-freeze on backup. ---
  'recipe[munchbox_base::proxmox_vm]',
  # --- HostCertificate + TrustedUserCAKeys + authorized_principals. Every other node role carries this; without it sshd presents a bare host key and anything verifying against the CA refuses the host. ---
  'recipe[munchbox_base::sshd_ca]',
  'role[vault_agent]',
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  'role[consul_client]',
  'recipe[cinc_server::install]',
  'recipe[cinc_server::configure]',
  'recipe[cinc_server::bootstrap]',
  'recipe[cinc_server::register]',
)
