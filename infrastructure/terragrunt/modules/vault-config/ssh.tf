# -------------------------------------------------------------------------------
# SSH CERTIFICATE AUTHORITY
#
# Project: Munchbox / Author: Alex Freidah
#
# Two separate SSH secrets engines for host and client certificate signing.
# Eliminates static SSH key distribution and known_hosts management.
#
# - ssh-host-signer: Signs node host keys (clients trust CA, not individual keys)
# - ssh-client-signer: Signs user/service keys (servers trust CA, not authorized_keys)
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# SSH HOST SIGNER
# -------------------------------------------------------------------------

resource "vault_mount" "ssh_host_signer" {
  count       = var.ssh_ca_enabled ? 1 : 0
  path        = "ssh-host-signer"
  type        = "ssh"
  description = "SSH CA for signing host keys"
}

resource "vault_ssh_secret_backend_ca" "host" {
  count                = var.ssh_ca_enabled ? 1 : 0
  backend              = vault_mount.ssh_host_signer[0].path
  generate_signing_key = true
}

resource "vault_ssh_secret_backend_role" "host_signer" {
  count                   = var.ssh_ca_enabled ? 1 : 0
  name                    = "host-signer"
  backend                 = vault_mount.ssh_host_signer[0].path
  key_type                = "ca"
  allow_host_certificates = true
  allow_bare_domains      = true
  allow_subdomains        = true
  allowed_domains         = "*"
  ttl                     = tostring(8760 * 3600)
  max_ttl                 = tostring(87600 * 3600)
  algorithm_signer        = "rsa-sha2-256"
}

# -------------------------------------------------------------------------
# SSH CLIENT SIGNER
# -------------------------------------------------------------------------

resource "vault_mount" "ssh_client_signer" {
  count       = var.ssh_ca_enabled ? 1 : 0
  path        = "ssh-client-signer"
  type        = "ssh"
  description = "SSH CA for signing user and service keys"
}

resource "vault_ssh_secret_backend_ca" "client" {
  count                = var.ssh_ca_enabled ? 1 : 0
  backend              = vault_mount.ssh_client_signer[0].path
  generate_signing_key = true
}

# Interactive user access - short-lived certs for human SSH sessions
resource "vault_ssh_secret_backend_role" "client_user" {
  count                   = var.ssh_ca_enabled ? 1 : 0
  name                    = "client-user"
  backend                 = vault_mount.ssh_client_signer[0].path
  key_type                = "ca"
  allow_user_certificates = true
  allowed_users           = "root,ubuntu"
  default_user            = "root"
  ttl                     = tostring(8 * 3600)
  max_ttl                 = tostring(24 * 3600)

  default_extensions = {
    "permit-pty"              = ""
    "permit-agent-forwarding" = ""
  }
}

# Service access - medium-lived certs for automated SSH (temporal worker, etc.)
resource "vault_ssh_secret_backend_role" "client_service" {
  count                   = var.ssh_ca_enabled ? 1 : 0
  name                    = "client-service"
  backend                 = vault_mount.ssh_client_signer[0].path
  key_type                = "ca"
  allow_user_certificates = true
  allowed_users           = "root,ubuntu"
  default_user            = "root"
  ttl                     = tostring(24 * 3600)
  max_ttl                 = tostring(8760 * 3600)

  # permit-port-forwarding is required for the cleanup worker's Docker-over-SSH
  # tunnel: registry GC, aptly cleanup, and the node-cleanup docker prune all
  # forward a streamlocal channel to the remote /var/run/docker.sock. Without
  # it the cert authenticates and runs commands fine, but the socket forward is
  # denied (surfaces as "ssh: rejected: connect failed").
  default_extensions = {
    "permit-pty"             = ""
    "permit-port-forwarding" = ""
  }
}
