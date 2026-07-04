#!/usr/bin/env bash
# ============================================================================
#  Family / parental protection for Pi-hole
# ----------------------------------------------------------------------------
#  On top of ad + malware blocking, this adds a child-safety layer:
#    1. Forces SafeSearch on Google, Bing & DuckDuckGo (no adult results).
#    2. Forces YouTube "Restricted Mode".
#    3. Adds adult / NSFW blocklists (config/blocklists-family.txt).
#    4. (optional) Adds a gambling/betting blocklist.
#    5. (optional) Blocks DNS-bypass tools (VPN / DoH / proxy) so the filter
#       can't be dodged from a device on the network.
#
#  It is called automatically by bootstrap.sh when FAMILY_MODE="true", or run
#  on its own any time:
#
#       sudo ./family-filter.sh
#
#  Idempotent: safe to run again. Works on Pi-hole v6 (preferred) and v5.
#
#    HONEST LIMITS: DNS filtering blocks known bad *domains* and forces safe
#  search - it cannot see inside an allowed website, cannot catch brand-new
#  adult sites until the lists update, and can be bypassed with a VPN unless you
#  also enable BLOCK_DNS_BYPASS and point the router's DNS only at this Pi. Use
#  it WITH device parental controls (Screen Time / Family Link) and conversation.
# ============================================================================
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo: sudo ./family-filter.sh" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/setup.conf"
FAMILY_LIST="$SCRIPT_DIR/../config/blocklists-family.txt"
GRAVITY_DB="/etc/pihole/gravity.db"

# Defaults (used if a value isn't set in setup.conf)
FAMILY_BLOCK_GAMBLING="true"
BLOCK_DNS_BYPASS="false"
YOUTUBE_MODE="strict"   # strict | moderate
# Optional: extra Google country domain your family uses (e.g. google.com.sa).
FAMILY_GOOGLE_CCTLD=""

# shellcheck source=/dev/null
[ -f "$CONF" ] && source "$CONF"

command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 required: apt-get install -y sqlite3" >&2; exit 1; }
[ -f "$GRAVITY_DB" ] || { echo "Install Pi-hole first (bootstrap.sh)." >&2; exit 1; }

echo "================================================"
echo "  Applying family / parental protection"
echo "================================================"

# ---------------------------------------------------------------------------
# 1 + 2.  Force SafeSearch + YouTube Restricted Mode via DNS CNAMEs
# ---------------------------------------------------------------------------
YT_TARGET="restrict.youtube.com"
[ "$YOUTUBE_MODE" = "moderate" ] && YT_TARGET="restrictmoderate.youtube.com"

# "from,to" - asking for <from> transparently returns the safe <to> instead.
MAPPINGS=(
  "www.google.com,forcesafesearch.google.com"
  "google.com,forcesafesearch.google.com"
  "www.bing.com,strict.bing.com"
  "bing.com,strict.bing.com"
  "duckduckgo.com,safe.duckduckgo.com"
  "www.duckduckgo.com,safe.duckduckgo.com"
  "www.youtube.com,$YT_TARGET"
  "m.youtube.com,$YT_TARGET"
  "youtube.com,$YT_TARGET"
  "youtubei.googleapis.com,$YT_TARGET"
  "youtube.googleapis.com,$YT_TARGET"
  "www.youtube-nocookie.com,$YT_TARGET"
)
if [ -n "$FAMILY_GOOGLE_CCTLD" ]; then
  MAPPINGS+=("$FAMILY_GOOGLE_CCTLD,forcesafesearch.google.com")
  MAPPINGS+=("www.$FAMILY_GOOGLE_CCTLD,forcesafesearch.google.com")
fi

echo "> Forcing SafeSearch + YouTube Restricted Mode ($YOUTUBE_MODE)..."
if command -v pihole-FTL >/dev/null 2>&1 && pihole-FTL --config dns.cnameRecords >/dev/null 2>&1; then
  # Pi-hole v6: one TOML array of "from,to" strings.
  JSON="["
  for m in "${MAPPINGS[@]}"; do JSON="$JSON\"$m\","; done
  JSON="${JSON%,}]"
  pihole-FTL --config dns.cnameRecords "$JSON" >/dev/null
  echo "  ✔ set via pihole-FTL (v6)"
else
  # Pi-hole v5: dnsmasq cname= lines.
  CF=/etc/dnsmasq.d/05-family-safesearch.conf
  : > "$CF"
  for m in "${MAPPINGS[@]}"; do echo "cname=${m}" >> "$CF"; done
  echo "  ✔ wrote $CF (v5)"
fi

# ---------------------------------------------------------------------------
# 3 + 4 + 5.  Add family blocklists
# ---------------------------------------------------------------------------
add_adlist() {  # $1=url  $2=comment
  local url="$1" comment="$2" exists
  case "$url" in http://*|https://*) ;; *) return 0 ;; esac
  exists="$(sqlite3 "$GRAVITY_DB" "SELECT COUNT(*) FROM adlist WHERE address='$url';" 2>/dev/null || echo 0)"
  if [ "${exists:-0}" -gt 0 ]; then
    echo "  = already present: $url"
  else
    sqlite3 "$GRAVITY_DB" "INSERT INTO adlist (address, enabled, comment) VALUES ('$url', 1, '$comment');"
    echo "  + added: $url"
  fi
}

echo "> Adding adult / NSFW blocklists..."
if [ -f "$FAMILY_LIST" ]; then
  while IFS= read -r raw || [ -n "$raw" ]; do
    url="$(printf '%s' "$raw" | sed 's/#.*//; s/[[:space:]]//g')"
    [ -n "$url" ] && add_adlist "$url" "family: NSFW (pi-hole family kit)"
  done < "$FAMILY_LIST"
else
  echo "  ! $FAMILY_LIST not found - skipping NSFW file."
fi

if [ "$FAMILY_BLOCK_GAMBLING" = "true" ]; then
  echo "> Adding gambling / betting blocklist..."
  add_adlist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/gambling.txt" \
             "family: gambling (pi-hole family kit)"
fi

if [ "$BLOCK_DNS_BYPASS" = "true" ]; then
  echo "> Blocking DNS-bypass tools (VPN / DoH / proxy)..."
  echo "  ! Note: this can also block a legitimate VPN you use. Disable BLOCK_DNS_BYPASS if that's a problem."
  add_adlist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/doh-vpn-proxy-bypass.txt" \
             "family: DNS-bypass block (pi-hole family kit)"
fi

# ---------------------------------------------------------------------------
# Rebuild + restart
# ---------------------------------------------------------------------------
echo "> Rebuilding the block database (gravity)..."
pihole -g
echo "> Restarting DNS..."
pihole restartdns >/dev/null 2>&1 || systemctl restart pihole-FTL || true

echo
echo "✔ Family protection is on: SafeSearch forced, YouTube restricted, adult sites blocked."
echo "  Test it: on a device using the Pi, search an adult term on Google - it should return safe results,"
echo "  and known adult sites should not open."
echo "  Reminder: pair this with device parental controls; no DNS filter is 100%."
