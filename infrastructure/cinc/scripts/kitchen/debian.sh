#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Munchbox cinc toolchain setup (Debian/Ubuntu)
#
# Installs cinc-workstation (chef + kitchen + inspec + cookstyle + chefspec
# all bundled) and the libvirt/KVM/vagrant stack needed to run Kitchen VMs.
# Idempotent -- re-running only installs what's missing.
#
# After this runs, every cookbook in infrastructure/cinc/cookbooks/ can use
# bare `kitchen` / `chef` / `cookstyle` / `inspec` from PATH; wrappers in
# /usr/local/bin do `env -i` so RVM / rbenv / bundler env can't pollute the
# cinc-workstation embedded ruby.
# -------------------------------------------------------------------------------

set -euo pipefail

# --- Install cinc-workstation if missing ---
if [[ ! -x /opt/cinc-workstation/bin/kitchen ]]; then
  echo "==> Installing cinc-workstation..."
  curl -L https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -P cinc-workstation
fi

# --- Install env-isolating wrappers in /usr/local/bin ---
echo "==> Installing cinc-workstation wrappers to /usr/local/bin..."
WRAPPER=/usr/local/bin/_cinc-wrapper
sudo tee "$WRAPPER" >/dev/null <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Runs a cinc-workstation binary with a clean env so RVM/rbenv/bundler
# settings from the calling shell can't pollute gem resolution.
set -e
tool=$(basename "$0")
exec env -i HOME="$HOME" TERM="${TERM:-xterm}" \
  PATH=/opt/cinc-workstation/bin:/usr/local/bin:/usr/bin:/bin \
  "/opt/cinc-workstation/bin/$tool" "$@"
WRAPPER_EOF
sudo chmod +x "$WRAPPER"

for tool in kitchen chef cookstyle inspec cinc-auditor cinc berks knife ohai rspec; do
  [[ -x "/opt/cinc-workstation/bin/$tool" ]] || continue
  sudo ln -sf "$WRAPPER" "/usr/local/bin/$tool"
done

# --- Install KVM/libvirt + vagrant + vagrant-libvirt ---
pkgs=(qemu-kvm libvirt-daemon-system libvirt-clients ebtables dnsmasq-base
      bridge-utils vagrant vagrant-libvirt)
if ! dpkg -s "${pkgs[@]}" >/dev/null 2>&1; then
  echo "==> Installing KVM + libvirt + vagrant-libvirt..."
  sudo apt-get update
  sudo apt-get install -y "${pkgs[@]}"
fi

# --- Add the calling user to libvirt + kvm groups ---
if ! id -nG "$USER" | grep -qw libvirt; then
  echo "==> Adding $USER to libvirt + kvm groups (log out/in to take effect)"
  sudo usermod -aG libvirt,kvm "$USER"
fi

echo ""
echo "Kitchen toolchain ready."
echo "If the wrappers aren't in PATH, open a new shell."
