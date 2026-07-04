#!/usr/bin/env bash
# ============================================================================
#  Back up this Pi-hole's full configuration (a "Teleporter" archive).
#  The resulting file can be RESTORED on any Pi-hole from the admin page
#  (Settings → Teleporter → Restore) — handy when you build a Pi for a friend
#  and want the same allowlists/blocklists.
#
#       sudo ./backup.sh              # writes into the current folder
#       sudo ./backup.sh /mnt/usb     # writes into a folder you choose
# ============================================================================
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo: sudo ./backup.sh" >&2; exit 1; }

OUT_DIR="${1:-$PWD}"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
HOST="$(hostname)"
OUT_FILE="$OUT_DIR/pihole-backup-${HOST}-${STAMP}"

echo "› Creating backup..."
if command -v pihole-FTL >/dev/null 2>&1 && pihole-FTL --teleporter >/dev/null 2>&1; then
  # Pi-hole v6: writes a .zip into the current directory; move it to OUT_FILE
  NEWEST="$(ls -t ./*teleporter*.zip 2>/dev/null | head -n1 || true)"
  if [ -n "${NEWEST:-}" ]; then
    mv "$NEWEST" "${OUT_FILE}.zip"
    echo "  ✔ ${OUT_FILE}.zip"
  else
    echo "  ! pihole-FTL --teleporter ran but no zip was found. Check the current folder." >&2
    exit 1
  fi
elif pihole -a -t "${OUT_FILE}.tar.gz" >/dev/null 2>&1; then
  # Pi-hole v5
  echo "  ✔ ${OUT_FILE}.tar.gz"
else
  echo "  ✘ Could not create a backup with either v6 or v5 method." >&2
  exit 1
fi
echo "Keep this file safe. Restore it on any Pi-hole: Settings → Teleporter → Restore."
