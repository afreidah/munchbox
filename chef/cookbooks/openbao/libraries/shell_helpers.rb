# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  libraries/shell_helpers.rb — OpenBao Cluster Management Library
#
#  Helpers for managing shell commands
# ------------------------------------------------------------------------------

module OpenBao
  CA_BUNDLE = '/opt/openbao/tls/ssl-bundle.crt'

  module ShellHelpers
    # -----------------------------------------------------------------------------
    # shell_out — run a command, capture its stdout/stderr, but do not error on non-zero exit
    # -----------------------------------------------------------------------------

    def shell_out(cmd, **opts)
      sh = Mixlib::ShellOut.new(cmd, **opts)
      sh.run_command
      sh
    end

    # -----------------------------------------------------------------------------
    # shell_out! — run a command and raise Mixlib::ShellOut::ShellCommandFailed on any non-zero exit
    # -----------------------------------------------------------------------------

    def shell_out!(cmd, **opts)
      sh = Mixlib::ShellOut.new(cmd, **opts)
      sh.run_command
      sh.error!
      sh
    end

    # -----------------------------------------------------------------------------
    # Helpers for building shell env:
    #   - BAO_ADDR / VAULT_ADDR
    #   - BAO_CACERT / VAULT_CACERT
    #   - optional SKIP_VERIFY & SNI
    # -----------------------------------------------------------------------------

    def shell_env(addr:, skip_verify: false, sni: nil)
      env = {
        'BAO_ADDR' => addr,
        'VAULT_ADDR' => addr,
        'BAO_CACERT' => CA_BUNDLE,
        'VAULT_CACERT' => CA_BUNDLE,
      }
      if skip_verify
        env['BAO_SKIP_VERIFY']   = 'true'
        env['VAULT_SKIP_VERIFY'] = 'true'
      end
      env['VAULT_TLS_SERVER_NAME'] = sni if sni.to_s != ''
      env
    end
  end
end
