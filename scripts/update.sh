#!/usr/bin/env bash
# ============================================================================
#  Keep Pi-hole (and the operating system) up to date.
#  Safe to run any time — recommended once a month.
#
#       sudo ./update.sh
# ============================================================================
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo: sudo ./update.sh" >&2; exit 1; }

echo "› Updating the operating system..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get autoremove -y

echo "› Updating Pi-hole..."
pihole -up

echo "› Refreshing the blocklists (gravity)..."
pihole -g

echo "✔ Everything is up to date."
