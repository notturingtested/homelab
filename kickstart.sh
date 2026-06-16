#!/usr/bin/env bash
set -euo pipefail

# Kickstart a homelab node from a NixOS live ISO
#
# Run:
#   wget -O /tmp/kickstart.sh https://raw.githubusercontent.com/notturingtested/homelab/main/kickstart.sh
#   bash /tmp/kickstart.sh

echo "=== Homelab Node Kickstart ==="
echo ""

# Detect disks
echo "Available disks:"
lsblk -d -o NAME,SIZE,MODEL | grep -v "loop\|sr\|ram\|NAME"
echo ""

# Auto-pick the largest non-USB disk, or prompt
DISK=""
CANDIDATE=$(lsblk -d -b -o NAME,SIZE,TRAN | grep -v "loop\|sr\|ram\|NAME" | grep -v "usb" | sort -k2 -rn | head -1 | awk '{print $1}')
if [ -n "$CANDIDATE" ]; then
  SIZE=$(lsblk -d -o NAME,SIZE | grep "^${CANDIDATE}" | awk '{print $2}')
  read -rp "Use /dev/${CANDIDATE} (${SIZE})? [Y/n]: " CONFIRM
  if [[ "${CONFIRM:-Y}" =~ ^[Yy]?$ ]]; then
    DISK="/dev/${CANDIDATE}"
  fi
fi
if [ -z "$DISK" ]; then
  read -rp "Enter disk (e.g., /dev/sda, /dev/nvme0n1): " DISK
fi

# Hostname
read -rp "Hostname [node1]: " HOSTNAME
HOSTNAME="${HOSTNAME:-node1}"

# Secrets
read -rp "Tailscale auth key (tskey-auth-...): " TS_KEY
read -rp "GitHub runner token: " GH_TOKEN

echo ""
echo "==> Installing to ${DISK} as ${HOSTNAME}"
echo "    THIS WILL WIPE ${DISK}"
read -rp "Continue? [y/N]: " GO
if [[ ! "${GO}" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# Fetch repo
echo "==> Downloading homelab config..."
wget -qO /tmp/homelab.tar.gz https://github.com/notturingtested/homelab/archive/main.tar.gz
tar xzf /tmp/homelab.tar.gz -C /tmp
cd /tmp/homelab-main/nixos

# Run bootstrap
echo "==> Running bootstrap..."
bash ./bootstrap.sh "${HOSTNAME}" "${DISK}" "${TS_KEY}" "${GH_TOKEN}"

echo ""
echo "==> All done. Rebooting in 5 seconds... (Ctrl+C to cancel)"
sleep 5
reboot
