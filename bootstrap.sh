#!/usr/bin/env bash
set -euo pipefail

# Bootstrap an Ubuntu Server node as a Docker + GHA runner
#
# Usage: ./bootstrap.sh <tailscale-authkey> <github-pat> [hostname]
#
# Run this after a fresh Ubuntu Server install:
#   curl -sL https://raw.githubusercontent.com/notturingtested/homelab/main/bootstrap.sh | sudo bash -s -- tskey-auth-XXXXX github_pat_XXXXX node1

TS_AUTHKEY="${1:?Usage: $0 <tailscale-authkey> <github-pat> [hostname]}"
GH_PAT="${2:?Provide GitHub PAT with admin:org or repo Administration permission}"
HOSTNAME="${3:-node1}"

echo "==> Setting hostname to ${HOSTNAME}"
hostnamectl set-hostname "${HOSTNAME}"

echo "==> Configuring lid close to ignore (laptop stays on)"
mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\n' > /etc/systemd/logind.conf.d/lid.conf
systemctl restart systemd-logind
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

echo "==> Enabling unattended upgrades"
apt-get update
apt-get install -y unattended-upgrades
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
printf 'Unattended-Upgrade::Allowed-Origins {\n  "${distro_id}:${distro_codename}";\n  "${distro_id}:${distro_codename}-security";\n  "${distro_id}ESMApps:${distro_codename}-apps-security";\n  "${distro_id}ESM:${distro_codename}-infra-security";\n  "Docker:${distro_codename}";\n};\nUnattended-Upgrade::Automatic-Reboot "true";\nUnattended-Upgrade::Automatic-Reboot-Time "04:00";\n' > /etc/apt/apt.conf.d/50unattended-upgrades

echo "==> Installing Docker"
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey "${TS_AUTHKEY}" --ssh --accept-routes

echo "==> Setting up GitHub Actions runner"
useradd -m -s /bin/bash runner || true
usermod -aG docker runner

RUNNER_HOME="/home/runner/actions-runner"
mkdir -p "${RUNNER_HOME}"

# Get latest runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | tar xz -C "${RUNNER_HOME}"
chown -R runner:runner "${RUNNER_HOME}"

# Exchange PAT for a runner registration token
echo "==> Getting runner registration token..."
GH_RUNNER_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${GH_PAT}" \
  https://api.github.com/repos/handshapes/handshapes/actions/runners/registration-token \
  | grep -oP '"token"\s*:\s*"\K[^"]+')

if [ -z "${GH_RUNNER_TOKEN}" ]; then
  echo "ERROR: Failed to get registration token. Check your PAT permissions."
  exit 1
fi

# Configure runner (must run as runner user from the runner directory)
su - runner -c "cd ${RUNNER_HOME} && ./config.sh \
  --url https://github.com/handshapes/handshapes \
  --token ${GH_RUNNER_TOKEN} \
  --name ${HOSTNAME} \
  --labels ubuntu,docker,self-hosted \
  --unattended \
  --replace"

# Install as service
cd "${RUNNER_HOME}"
./svc.sh install runner
./svc.sh start

echo ""
echo "==> Done! ${HOSTNAME} is now:"
echo "    - On your Tailscale network"
echo "    - Running as a GitHub Actions runner"
echo "    - Docker enabled"
echo "    - Lid close ignored"
echo "    - Unattended upgrades enabled (reboots at 4am)"
