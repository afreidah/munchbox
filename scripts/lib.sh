#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# WARP Lib - Shared helpers for warp-on.sh / warp-off.sh
#
# Project: Munchbox / Author: Alex Freidah
#
# Sourced, not executed. Holds the resolv.conf handling both scripts need so the
# split-resolver can never be left in the request path without a tunnel behind it.
# -------------------------------------------------------------------------------

# Consul answers under node.<domain> and service.<domain>, and the dashboards
# live under munchbox.cc, so all three belong in the search list or an
# unqualified name like `goren` never resolves.
CONSUL_SEARCH_DOMAINS="node.consul service.consul munchbox.cc"

# Holds the pre-tunnel resolv.conf while the split-resolver owns the real one, so
# a restore puts back every nameserver, search and options line verbatim.
RESOLV_STASH=/var/lib/munchbox/resolv.conf.orig

# warp-cli authorizes against the user that registered the client, so a call made
# as root under sudo is refused with "Operation not authorized in this context".
warp_cli() {
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    sudo -u "$SUDO_USER" warp-cli "$@"
  else
    warp-cli "$@"
  fi
}

# systemctl start returns before warp-svc opens its socket, so the first
# warp-cli call races the daemon and fails with "No such file or directory".
wait_for_warp_daemon() {
  local i
  for i in {1..30}; do
    warp_cli status >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

# True when WARP carries traffic. The DoH, DoT and proxy modes still reach
# Connected but route nothing, so a tunnel in one of those is useless here.
warp_mode_routes() {
  warp_cli settings 2>/dev/null | grep -qE 'Mode:[[:space:]]*(Warp|WarpWithDnsOverHttps)[[:space:]]*$'
}

# Probe a host that only resolves off-tunnel, so a dead split-resolver reads as a
# failure instead of hanging against unreachable homelab servers.
dns_works() {
  getent hosts api.cloudflareclient.com >/dev/null 2>&1
}

consul_resolvers() {
  sed -n 's|^server=/consul/||p' /etc/dnsmasq.d/consul.conf 2>/dev/null
}

# Connected is reported before the tunnel interface leaves state DOWN, so wait
# for a homelab resolver to actually answer before handing DNS to dnsmasq.
wait_for_tunnel_dns() {
  local i resolver
  for i in {1..30}; do
    while read -r resolver; do
      [[ -n "$resolver" ]] || continue
      dig +time=2 +tries=1 "@${resolver}" consul SOA >/dev/null 2>&1 && return 0
    done < <(consul_resolvers)
    sleep 1
  done
  return 1
}

resolv_search_domains() {
  grep -hE '^(search|domain)[[:space:]]' /etc/resolv.conf 2>/dev/null |
    sed -E 's/^[a-z]+[[:space:]]+//'
}

# A resolv.conf listing only loopback nameservers belongs to dnsmasq or the WARP
# daemon, and resolves nothing once either stops; it is never worth stashing.
has_real_nameserver() {
  grep -E '^nameserver[[:space:]]+' "$1" 2>/dev/null |
    grep -qvE '^nameserver[[:space:]]+127\.'
}

stash_resolv() {
  [[ -f "$RESOLV_STASH" ]] && return 0
  has_real_nameserver /etc/resolv.conf || return 0
  sudo mkdir -p "$(dirname "$RESOLV_STASH")"
  sudo cp /etc/resolv.conf "$RESOLV_STASH"
}

# Point resolv.conf at the split-resolver, keeping the existing search domains
# alongside Consul's; a bare nameserver line breaks every unqualified hostname.
write_split_resolv() {
  local search
  search=$( {
    printf '%s\n' "$CONSUL_SEARCH_DOMAINS" | tr ' ' '\n'
    resolv_search_domains | tr ' ' '\n'
  } | awk 'NF && !seen[$0]++' | tr '\n' ' ')
  search="${search% }"

  sudo chattr -i /etc/resolv.conf 2>/dev/null || true
  {
    printf 'nameserver 127.0.0.1\n'
    printf 'search %s\n' "$search"
  } | sudo tee /etc/resolv.conf > /dev/null
  sudo chattr +i /etc/resolv.conf 2>/dev/null || true
  echo "$search"
}

split_resolv_active() {
  grep -q '^nameserver 127\.0\.0\.1' /etc/resolv.conf 2>/dev/null
}

# WARP keeps rewriting resolv.conf for a while after it reports Connected, and
# clears the immutable flag to do it, so one write is not enough to win.
ensure_split_resolv() {
  local i search
  for i in {1..10}; do
    search=$(write_split_resolv)
    sleep 2
    if split_resolv_active; then
      echo "Consul split-DNS active (resolv.conf -> 127.0.0.1, search: ${search}, locked)."
      return 0
    fi
  done
  echo "WARP kept reclaiming resolv.conf; split-DNS is not active." >&2
  return 1
}

# Put a real upstream resolver back when resolv.conf still points at the stopped
# split-resolver; WARP does not own this file, so nothing else restores it.
restore_upstream_dns() {
  sudo chattr -i /etc/resolv.conf 2>/dev/null || true

  # A stash means we overwrote the file, whatever it holds now; WARP may have
  # replaced ours in the meantime, so the stash decides, not the current contents.
  if [[ -f "$RESOLV_STASH" ]]; then
    if has_real_nameserver "$RESOLV_STASH"; then
      sudo cp "$RESOLV_STASH" /etc/resolv.conf
      sudo rm -f "$RESOLV_STASH"
      if dns_works; then
        echo "Restored pre-tunnel resolv.conf."
        return 0
      fi
      # Stashed on a different network; its resolvers are unreachable here.
    else
      sudo rm -f "$RESOLV_STASH"
    fi
  fi

  has_real_nameserver /etc/resolv.conf && dns_works && return 0

  write_nm_resolv
}

# Rebuild resolv.conf from NetworkManager's live view, keeping every nameserver
# and the search list rather than collapsing to a single bare nameserver line.
write_nm_resolv() {
  local ns search one
  ns=$(nmcli -g IP4.DNS device show 2>/dev/null | tr '|' '\n' | sed 's/^ *//' | grep -vE '^(127\.|$)' || true)
  search=$(nmcli -g IP4.DOMAIN device show 2>/dev/null | tr '|' '\n' | sed 's/^ *//' | grep -v '^$' | tr '\n' ' ' || true)
  [[ -n "$ns" ]] || ns="1.1.1.1"

  {
    printf '# Written by warp-off.sh\n'
    [[ -n "$search" ]] && printf 'search %s\n' "${search% }"
    while read -r one; do
      [[ -n "$one" ]] && printf 'nameserver %s\n' "$one"
    done <<< "$ns"
  } | sudo tee /etc/resolv.conf > /dev/null
  echo "Rebuilt resolv.conf from NetworkManager ($(echo "$ns" | tr '\n' ' '))."
}
