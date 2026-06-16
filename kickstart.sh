#!/usr/bin/env bash
set -euo pipefail

# Kickstart a homelab node from a NixOS live ISO
#
# Usage:
#   bash /tmp/kickstart.sh <tailscale-key> <github-runner-token> [hostname] [disk]
#
# Example:
#   bash /tmp/kickstart.sh tskey-auth-xxxxx AXXXXX node1 /dev/sda

TS_KEY="${1:?Usage: $0 <tailscale-key> <github-runner-token> [hostname] [disk]}"
GH_TOKEN="${2:?Provide GitHub runner token}"
HOSTNAME="${3:-node1}"

# Auto-detect disk if not provided
if [ -n "${4:-}" ]; then
  DISK="$4"
else
  echo "Detecting disk..."
  lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v "loop\|sr\|ram\|NAME"
  DISK="/dev/$(lsblk -d -b -o NAME,SIZE,TRAN | grep -v "loop\|sr\|ram\|NAME" | grep -v "usb" | sort -k2 -rn | head -1 | awk '{print $1}')"
  echo "Auto-selected: ${DISK}"
fi

echo ""
echo "=== Homelab Kickstart ==="
echo "  Host: ${HOSTNAME}"
echo "  Disk: ${DISK} (WILL BE WIPED)"
echo ""
echo "Starting in 5 seconds... Ctrl+C to abort."
sleep 5

# Fetch repo
echo "==> Downloading homelab config..."
curl -sL -o /tmp/homelab.tar.gz https://github.com/notturingtested/homelab/archive/main.tar.gz
tar xzf /tmp/homelab.tar.gz -C /tmp
cd /tmp/homelab-main/nixos

# Run bootstrap
echo "==> Running bootstrap..."
bash ./bootstrap.sh "${HOSTNAME}" "${DISK}" "${TS_KEY}" "${GH_TOKEN}"

echo ""
echo "==> All done. Rebooting in 5 seconds... (Ctrl+C to cancel)"
sleep 5
reboot
