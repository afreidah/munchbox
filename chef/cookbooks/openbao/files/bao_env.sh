# /etc/profile.d/bao.sh

# --- OpenBao CLI defaults (fine for all shells that source this) ---
export VAULT_ADDR="https://$(hostname -f):8200"
export BAO_CACERT="/opt/openbao/tls/ssl-bundle.crt"

# --- Only tweak interactive bash sessions ---
if [ -n "$BASH_VERSION" ] && [ -n "$PS1" ]; then
  set -o vi
  alias ls="ls -ltr --color"

  # --- Prompt: user@host:cwd $ ---
  PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "
fi
