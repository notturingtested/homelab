{ config, lib, pkgs, ... }:

{
  # Tailscale
  services.tailscale.enable = true;

  # Auto-authenticate on first boot using an auth key
  # Set the auth key in /etc/tailscale/authkey on the install media,
  # or use the oneshot service below with a pre-auth key from:
  # https://login.tailscale.com/admin/settings/keys
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      # Wait for tailscaled to be ready
      sleep 2

      # Check if already authenticated
      status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
      if [ "$status" = "Running" ]; then
        exit 0
      fi

      # Authenticate using the auth key file
      if [ -f /etc/tailscale/authkey ]; then
        ${pkgs.tailscale}/bin/tailscale up --authkey file:/etc/tailscale/authkey --ssh
      fi
    '';
  };

  # Allow tailscale traffic
  networking.firewall.checkReversePath = "loose";
}
