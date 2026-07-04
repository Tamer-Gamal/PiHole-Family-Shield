#!/usr/bin/env bash
# ============================================================================
#  Add the curated blocklists from ../config/blocklists.txt into Pi-hole.
#  Idempotent: running it again will not create duplicates.
#
#       sudo ./add-blocklists.sh
# ============================================================================
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo: sudo ./add-blocklists.sh" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_FILE="$SCRIPT_DIR/../config/blocklists.txt"
GRAVITY_DB="/etc/pihole/gravity.db"

[ -f "$LIST_FILE" ]  || { echo "Missing $LIST_FILE" >&2; exit 1; }
[ -f "$GRAVITY_DB" ] || { echo "Pi-hole gravity DB not found. Install Pi-hole first (bootstrap.sh)." >&2; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 is required. Install it: apt-get install -y sqlite3" >&2; exit 1; }

added=0
skipped=0
while IFS= read -r raw || [ -n "$raw" ]; do
  # strip inline whitespace / ignore blanks and comments
  url="$(printf '%s' "$raw" | sed 's/#.*//; s/[[:space:]]//g')"
  [ -z "$url" ] && continue
  case "$url" in http://*|https://*) ;; *) continue ;; esac

  exists="$(sqlite3 "$GRAVITY_DB" \
    "SELECT COUNT(*) FROM adlist WHERE address='$url';" 2>/dev/null || echo 0)"
  if [ "${exists:-0}" -gt 0 ]; then
    echo "  = already present: $url"
    skipped=$((skipped+1))
  else
    sqlite3 "$GRAVITY_DB" \
      "INSERT INTO adlist (address, enabled, comment) VALUES ('$url', 1, 'curated: homelab-hive pi-hole kit');"
    echo "  + added: $url"
    added=$((added+1))
  fi
done < "$LIST_FILE"

echo "Adlists added: $added   already present: $skipped"
echo "Updating the block database (gravity)..."
pihole -g
echo "Done."
