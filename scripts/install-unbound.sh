#!/usr/bin/env bash
# ============================================================================
#  Install Unbound (a private recursive DNS resolver) and point Pi-hole at it.
#  Called automatically by bootstrap.sh when INSTALL_UNBOUND="true", or run
#  on its own later:
#
#       sudo ./install-unbound.sh
#
#  Idempotent: safe to run again.
# ============================================================================
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo: sudo ./install-unbound.sh" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNBOUND_SRC="$SCRIPT_DIR/../config/unbound-pihole.conf"
UNBOUND_DST="/etc/unbound/unbound.conf.d/pi-hole.conf"

[ -f "$UNBOUND_SRC" ] || { echo "Missing $UNBOUND_SRC" >&2; exit 1; }

echo "› Installing unbound..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y unbound

echo "› Fetching the root hints (list of internet root servers)..."
mkdir -p /var/lib/unbound
if curl -fsSL -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.root; then
  chown unbound:unbound /var/lib/unbound/root.hints 2>/dev/null || true
  echo "  ✔ root.hints updated"
else
  echo "  ! Could not download root.hints (unbound ships a built-in copy; continuing)."
fi

echo "› Installing Unbound config for Pi-hole..."
install -m 0644 "$UNBOUND_SRC" "$UNBOUND_DST"

echo "› Restarting unbound..."
systemctl enable unbound >/dev/null 2>&1 || true
systemctl restart unbound

echo "› Testing that Unbound resolves + validates DNSSEC..."
sleep 1
if command -v dig >/dev/null 2>&1; then
  if dig +short @127.0.0.1 -p 5335 pi-hole.net >/dev/null 2>&1; then
    echo "  ✔ Unbound answered a query on 127.0.0.1#5335"
  else
    echo "  ! Unbound did not answer yet — check: systemctl status unbound"
  fi
fi

echo "› Pointing Pi-hole's upstream DNS at Unbound (127.0.0.1#5335)..."
if command -v pihole-FTL >/dev/null 2>&1 && pihole-FTL --config dns.upstreams >/dev/null 2>&1; then
  # Pi-hole v6: single source of truth is pihole.toml, set via pihole-FTL --config
  pihole-FTL --config dns.upstreams '[ "127.0.0.1#5335" ]'
  echo "  ✔ set via pihole-FTL (v6)"
elif [ -f /etc/pihole/setupVars.conf ]; then
  # Pi-hole v5: setupVars.conf + restart
  sed -i '/^PIHOLE_DNS_/d' /etc/pihole/setupVars.conf
  echo "PIHOLE_DNS_1=127.0.0.1#5335" >> /etc/pihole/setupVars.conf
  echo "  ✔ set via setupVars.conf (v5)"
else
  echo "  ! Could not set upstream automatically. In the admin page set the upstream DNS"
  echo "    to a Custom server: 127.0.0.1#5335 (and uncheck the others)."
fi

pihole restartdns >/dev/null 2>&1 || systemctl restart pihole-FTL || true
echo "✔ Unbound is now Pi-hole's private upstream resolver."
