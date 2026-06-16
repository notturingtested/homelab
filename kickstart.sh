#!/usr/bin/env bash
set -euo pipefail

# Kickstart from a fresh Ubuntu Server install
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/notturingtested/homelab/main/kickstart.sh | sudo bash -s -- <ts-key> <gh-token> [hostname]

TS_KEY="${1:?Usage: $0 <tailscale-key> <github-runner-token> [hostname]}"
GH_TOKEN="${2:?Provide GitHub runner token}"
HOSTNAME="${3:-node1}"

curl -sL -o /tmp/bootstrap.sh https://raw.githubusercontent.com/notturingtested/homelab/main/bootstrap.sh
bash /tmp/bootstrap.sh "${TS_KEY}" "${GH_TOKEN}" "${HOSTNAME}"
