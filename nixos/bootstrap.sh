#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a new node from a NixOS live USB
#
# Usage: ./bootstrap.sh <hostname> <disk> <tailscale-authkey> <github-runner-token>
#
# Example: ./bootstrap.sh node1 /dev/sda tskey-auth-xxxxx ghp_xxxxx

HOSTNAME="${1:?Usage: $0 <hostname> <disk> <tailscale-authkey> <github-runner-token>}"
DISK="${2:?Provide target disk (e.g., /dev/sda, /dev/nvme0n1)}"
TS_AUTHKEY="${3:?Provide Tailscale pre-auth key}"
GH_RUNNER_TOKEN="${4:?Provide GitHub runner registration token}"

echo "==> Bootstrapping ${HOSTNAME} on ${DISK}"

# Partition and mount using disko
echo "==> Running disko to partition ${DISK}"
nix run github:nix-community/disko -- --mode disko --flake ".#${HOSTNAME}" --arg device "\"${DISK}\""

# Mount the filesystem
mount /dev/disk/by-partlabel/root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-partlabel/ESP /mnt/boot

# Install NixOS
echo "==> Installing NixOS for ${HOSTNAME}"
nixos-install --flake ".#${HOSTNAME}" --no-root-passwd

# Place secrets
echo "==> Writing Tailscale auth key"
mkdir -p /mnt/etc/tailscale
echo "${TS_AUTHKEY}" > /mnt/etc/tailscale/authkey
chmod 600 /mnt/etc/tailscale/authkey

echo "==> Writing GitHub runner token"
mkdir -p /mnt/etc/github-runner
echo "${GH_RUNNER_TOKEN}" > /mnt/etc/github-runner/token
chmod 600 /mnt/etc/github-runner/token

echo "==> Writing SSH authorized key"
mkdir -p /mnt/etc/ssh/authorized_keys
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /mnt/etc/ssh/authorized_keys/admin
elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
  cp "$HOME/.ssh/id_ed25519.pub" /mnt/etc/ssh/authorized_keys/admin
else
  echo "WARNING: No SSH key found. Place your public key at /etc/ssh/authorized_keys/admin after install."
fi
chmod 644 /mnt/etc/ssh/authorized_keys/admin 2>/dev/null || true

echo "==> Done! Reboot into the new system."
echo "    The node will auto-join Tailscale and register as a GitHub Actions runner."
