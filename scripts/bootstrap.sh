#!/usr/bin/env bash
# ============================================================================
#  Pi-hole one-shot bootstrap  -  turns a fresh Raspberry Pi into an ad-blocker
# ----------------------------------------------------------------------------
#  Run it like this (from this scripts/ folder), after editing setup.conf:
#
#       sudo ./bootstrap.sh
#
#  It is IDEMPOTENT: safe to run again. It will update an existing install
#  instead of breaking it. Targets Pi-hole v6 (current) with v5 fallbacks.
# ============================================================================
set -Eeuo pipefail

# --- pretty output ----------------------------------------------------------
c_ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
c_info() { printf '\033[1;36m> %s\033[0m\n' "$*"; }
c_warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
c_err()  { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; }
die()    { c_err "$*"; exit 1; }
trap 'c_err "Something failed on line $LINENO. Nothing was left half-done that a re-run cannot fix - read the message above, then run: sudo ./bootstrap.sh"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/setup.conf"

# --- 0. sanity checks -------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Please run with sudo:  sudo ./bootstrap.sh"
[ -f "$CONF" ] || die "No setup.conf found. Do:  cp setup.conf.example setup.conf  then edit it, then re-run."

# shellcheck source=/dev/null
source "$CONF"

: "${PIHOLE_HOSTNAME:?set PIHOLE_HOSTNAME in setup.conf}"
: "${PIHOLE_ADMIN_PASSWORD:?set PIHOLE_ADMIN_PASSWORD in setup.conf}"
: "${UPSTREAM_DNS_1:=1.1.1.1}"
: "${UPSTREAM_DNS_2:=1.0.0.1}"
: "${INSTALL_UNBOUND:=false}"
: "${ADD_CURATED_BLOCKLISTS:=true}"
: "${FAMILY_MODE:=true}"
: "${TIMEZONE:=UTC}"
: "${STATIC_IP:=}"
: "${STATIC_GATEWAY:=}"

if [ "$PIHOLE_ADMIN_PASSWORD" = "change-me-please" ]; then
  die "Please change PIHOLE_ADMIN_PASSWORD in setup.conf to your own password first."
fi

c_info "Detecting your network..."
PRIMARY_IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
[ -n "${PRIMARY_IFACE:-}" ] || die "Could not find your network interface. Is the Pi connected to the network?"
CURRENT_IP="$(ip -4 addr show "$PRIMARY_IFACE" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"
[ -n "${CURRENT_IP:-}" ] || die "Could not read this Pi's IP address on $PRIMARY_IFACE."
c_ok "Interface: $PRIMARY_IFACE   IP: $CURRENT_IP"

# --- 1. base system ---------------------------------------------------------
c_info "Setting hostname to '$PIHOLE_HOSTNAME' and timezone to '$TIMEZONE'..."
hostnamectl set-hostname "$PIHOLE_HOSTNAME" || c_warn "Could not set hostname (continuing)."
timedatectl set-timezone "$TIMEZONE" 2>/dev/null || c_warn "Unknown timezone '$TIMEZONE' (continuing)."

c_info "Updating the operating system (this can take a few minutes)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl ca-certificates sqlite3

# --- 2. optional static IP (advanced) --------------------------------------
if [ -n "$STATIC_IP" ]; then
  [ -n "$STATIC_GATEWAY" ] || die "STATIC_IP is set but STATIC_GATEWAY is empty. Set both, or clear both."
  if command -v nmcli >/dev/null 2>&1; then
    c_info "Assigning static IP $STATIC_IP via NetworkManager..."
    CON_NAME="$(nmcli -t -g GENERAL.CONNECTION device show "$PRIMARY_IFACE" | head -n1)"
    [ -n "$CON_NAME" ] || die "Could not find the NetworkManager connection for $PRIMARY_IFACE."
    nmcli connection modify "$CON_NAME" ipv4.addresses "$STATIC_IP" ipv4.gateway "$STATIC_GATEWAY" \
      ipv4.dns "127.0.0.1" ipv4.method manual
    c_warn "Static IP will apply after reboot. The address the Pi uses may change to ${STATIC_IP%/*}."
    CURRENT_IP="${STATIC_IP%/*}"
  else
    c_warn "nmcli not found - skipping static IP. Set a DHCP reservation in your router instead."
  fi
else
  c_warn "No static IP set. IMPORTANT: reserve $CURRENT_IP for this Pi in your router (DHCP reservation),"
  c_warn "so its address never changes. The guide shows how."
fi

# --- 3. Pi-hole install (unattended, idempotent) ---------------------------
if command -v pihole >/dev/null 2>&1; then
  c_info "Pi-hole already installed - repairing/updating instead of reinstalling..."
  pihole -up || c_warn "pihole -up returned non-zero (continuing)."
else
  c_info "Installing Pi-hole (unattended)..."
  # Pre-seed the installer so it asks nothing. v6 migrates these values.
  mkdir -p /etc/pihole
  cat > /etc/pihole/setupVars.conf <<EOF
PIHOLE_INTERFACE=$PRIMARY_IFACE
PIHOLE_DNS_1=$UPSTREAM_DNS_1
PIHOLE_DNS_2=$UPSTREAM_DNS_2
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=false
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=local
BLOCKING_ENABLED=true
EOF
  curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended \
    || die "Pi-hole installer failed. Check your internet connection and re-run."
fi
c_ok "Pi-hole core installed."

# --- 4. admin password (version-aware) -------------------------------------
c_info "Setting the admin web-page password..."
if pihole setpassword "$PIHOLE_ADMIN_PASSWORD" >/dev/null 2>&1; then
  c_ok "Password set (Pi-hole v6)."
elif pihole -a -p "$PIHOLE_ADMIN_PASSWORD" >/dev/null 2>&1; then
  c_ok "Password set (Pi-hole v5)."
else
  c_warn "Could not set the password automatically. Set it later with:  pihole setpassword"
fi

# --- 5. upstream DNS + Unbound ---------------------------------------------
if [ "$INSTALL_UNBOUND" = "true" ]; then
  c_info "Installing Unbound (private recursive DNS)..."
  "$SCRIPT_DIR/install-unbound.sh"
else
  c_info "Using upstream DNS $UPSTREAM_DNS_1 / $UPSTREAM_DNS_2 (already set)."
fi

# --- 6. curated blocklists --------------------------------------------------
if [ "$ADD_CURATED_BLOCKLISTS" = "true" ]; then
  c_info "Adding curated ad + malware/phishing blocklists..."
  "$SCRIPT_DIR/add-blocklists.sh" || c_warn "Blocklist step had a problem (continuing)."
fi

# --- 6b. family / kid protection (this kit's main purpose) ------------------
if [ "$FAMILY_MODE" = "true" ]; then
  c_info "Applying family protection: SafeSearch, YouTube Restricted Mode, adult + gambling blocking..."
  "$SCRIPT_DIR/family-filter.sh" || c_warn "Family-filter step had a problem (continuing)."
fi

c_info "Rebuilding the block database (gravity)..."
pihole -g || c_warn "Gravity update returned non-zero (continuing)."

# --- 7. done ----------------------------------------------------------------
BLOCKED="$(pihole -c -j 2>/dev/null | sed -n 's/.*"domains_being_blocked":\([0-9]*\).*/\1/p')"
echo
c_ok  "Pi-hole is ready!"
echo  "-----------------------------------------------------------------"
echo  "  Admin page : http://$CURRENT_IP/admin   (or http://$PIHOLE_HOSTNAME.local/admin)"
echo  "  Password   : the one you set in setup.conf"
[ -n "${BLOCKED:-}" ] && echo "  Blocking   : $BLOCKED domains"
[ "$FAMILY_MODE" = "true" ] && echo "  Family     : SafeSearch forced - YouTube restricted - adult/gambling blocked"
echo  "-----------------------------------------------------------------"
echo  "  NEXT STEP: tell your devices to use this Pi for DNS."
echo  "  Easiest: in your ROUTER, set the DNS server to  $CURRENT_IP  and reboot devices."
echo  "  The interactive guide walks you through it: pi-hole/guide/index.html"
echo
