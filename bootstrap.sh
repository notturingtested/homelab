#!/usr/bin/env bash
set -euo pipefail

# Bootstrap an Ubuntu Server node as a Docker + GHA runner
#
# Usage: ./bootstrap.sh <tailscale-authkey> <github-runner-token> [hostname]
#
# Run this after a fresh Ubuntu Server install:
#   curl -sL https://raw.githubusercontent.com/notturingtested/homelab/main/bootstrap.sh | bash -s -- tskey-auth-XXXXX GHTOKEN node1

TS_AUTHKEY="${1:?Usage: $0 <tailscale-authkey> <github-runner-token> [hostname]}"
GH_RUNNER_TOKEN="${2:?Provide GitHub runner registration token}"
HOSTNAME="${3:-node1}"

echo "==> Setting hostname to ${HOSTNAME}"
hostnamectl set-hostname "${HOSTNAME}"

echo "==> Installing Docker"
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey "${TS_AUTHKEY}" --ssh

echo "==> Setting up GitHub Actions runner"
useradd -m -s /bin/bash runner || true
usermod -aG docker runner

RUNNER_HOME="/home/runner/actions-runner"
mkdir -p "${RUNNER_HOME}"

# Get latest runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | tar xz -C "${RUNNER_HOME}"
chown -R runner:runner "${RUNNER_HOME}"

# Configure runner
cd "${RUNNER_HOME}"
sudo -u runner ./config.sh \
  --url "https://github.com/handshapes/handshapes" \
  --token "${GH_RUNNER_TOKEN}" \
  --name "${HOSTNAME}" \
  --labels "ubuntu,docker,self-hosted" \
  --unattended \
  --replace

# Install as service
./svc.sh install runner
./svc.sh start

echo "==> Enabling unattended upgrades"
apt-get install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UEOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
    "Docker:${distro_codename}";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
UEOF
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
AEOF

echo "==> Configuring lid close to ignore (laptop stays on)"
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/lid.conf << EOF
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
systemctl restart systemd-logind

echo ""
echo "==> Done! ${HOSTNAME} is now:"
echo "    - On your Tailscale network"
echo "    - Running as a GitHub Actions runner"
echo "    - Docker enabled"
