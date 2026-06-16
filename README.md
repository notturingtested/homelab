# Homelab

NixOS-based homelab running k3s across 4 laptops, managed via GitOps (Flux).

## Architecture

| Node | Role |
|------|------|
| node1 | k3s server (control plane) + worker |
| node2-4 | k3s agents |
| rpi | HomeKit + DNS (off-cluster) |

All nodes connected via Tailscale mesh. Apps deployed via FluxCD.

## Prerequisites (on your Mac)

```bash
# Install Nix (for building/testing configs locally)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh

# Install tools
nix profile install nixpkgs#kubectl nixpkgs#k9s nixpkgs#fluxcd nixpkgs#tailscale

# Generate a cluster token
mkdir -p nixos/secrets
openssl rand -hex 32 > nixos/secrets/k3s-token

# Get a Tailscale pre-auth key (reusable + ephemeral recommended)
# https://login.tailscale.com/admin/settings/keys
```

## Bootstrapping a Node

### 1. Prepare install media

Download the [NixOS minimal ISO](https://nixos.org/download/#nixos-iso) (x86_64) and flash it:

```bash
# Find your USB device
diskutil list

# Flash (replace diskN with your USB)
sudo dd if=nixos-minimal-*.iso of=/dev/rdiskN bs=4m status=progress
```

### 2. Copy this repo to a second USB

```bash
# Format a second USB as FAT32 or ext4, then:
cp -r . /Volumes/HOMELAB_USB/
```

Or use a single USB — after booting the ISO, pull the repo over the network:
```bash
git clone https://github.com/YOUR_USER/homelab /tmp/homelab
```

### 3. Boot the laptop

1. Plug in the NixOS USB
2. Boot from USB (usually F12/F2/Del for boot menu)
3. Connect to WiFi if needed: `nmcli device wifi connect SSID password PASS`

### 4. Run bootstrap

```bash
# Mount the repo USB if using a second stick
mount /dev/sdb1 /mnt/usb

# Run the bootstrap script
cd /mnt/usb/nixos  # or /tmp/homelab/nixos
./bootstrap.sh node1 /dev/sda tskey-auth-XXXXX
```

This will:
- Wipe and partition the target disk
- Install NixOS with your full config
- Write the Tailscale auth key and k3s token

### 5. Reboot

```bash
reboot
```

The node will:
- Auto-join your Tailscale network
- Auto-join the k3s cluster (node1 starts the server; others connect as agents)
- Start Docker
- Begin auto-upgrading nightly from this repo

### 6. Repeat for remaining nodes

```bash
# For each laptop, create its host config:
cp -r nixos/hosts/node1 nixos/hosts/node2

# Edit hardware.nix — run this ON the new laptop from the live USB:
nixos-generate-config --show-hardware-config > /tmp/hardware.nix
# Then paste into nixos/hosts/node2/hardware.nix

# Edit disk.nix — update the device path if different from /dev/sda

# Run bootstrap
./bootstrap.sh node2 /dev/nvme0n1 tskey-auth-XXXXX
```

## Cluster Setup (after all nodes are up)

### Grab kubeconfig

```bash
# From your Mac, over Tailscale:
ssh admin@node1 "sudo cat /etc/rancher/k3s/k3s.yaml" > kubeconfig
sed -i '' 's/127.0.0.1/node1/g' kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

kubectl get nodes
```

### Bootstrap FluxCD

```bash
flux bootstrap github \
  --owner=YOUR_USER \
  --repository=homelab \
  --path=cluster/flux \
  --personal
```

Flux will sync everything in `cluster/apps/` — Minecraft, ARC runners, etc.

## Day-to-day

| Task | How |
|------|-----|
| Deploy a new app | Add manifests to `cluster/apps/`, push to main |
| Update NixOS config | Edit `nixos/`, push to main — nodes auto-pull at 4am |
| Force update a node | `ssh admin@nodeN "sudo nixos-rebuild switch --flake github:YOU/homelab#nodeN"` |
| Check cluster | `kubectl get pods -A` or `k9s` |
| Access Minecraft | `node1.your-tailnet.ts.net:25565` (or expose via Tailscale Funnel) |

## Secrets Management

Secrets are **never** committed to the repo:
- `nixos/secrets/` is gitignored
- Tailscale auth keys are passed as CLI args during bootstrap
- k3s token is copied from `nixos/secrets/k3s-token` during bootstrap
- Kubernetes secrets (GitHub PAT for ARC, etc.) should use [sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) or [external-secrets](https://external-secrets.io/)

## TODOs

- [ ] Fill in SSH public key in `modules/common.nix`
- [ ] Update GitHub username in `common.nix` auto-upgrade URL
- [ ] Update tailnet domain in `modules/k3s.nix`
- [ ] Set up `hosts/node2`, `node3`, `node4` with hardware configs
- [ ] Add Pi config for HomeKit/DNS
- [ ] Configure sealed-secrets or external-secrets for k8s secrets
