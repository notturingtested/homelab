{ config, lib, pkgs, name, ... }:

{
  # Hostname
  networking.hostName = name;

  # Nix settings
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Auto-upgrade from flake repo
  system.autoUpgrade = {
    enable = true;
    flake = "github:notturingtested/homelab#${name}";
    flags = [ "--update-input" "nixpkgs" ];
    dates = "04:00";
    allowReboot = true;
    rebootWindow = {
      lower = "03:00";
      upper = "05:00";
    };
  };

  # Laptop power management
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
    lidSwitchDocked = "ignore";
  };
  powerManagement.enable = true;

  # Base packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
  ];

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Docker (for local dev, GHA runner DinD, etc.)
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Firewall — k3s and tailscale handle networking
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # User
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keyFiles = [
      /etc/ssh/authorized_keys/admin
    ];
  };

  # Timezone
  time.timeZone = "America/Denver";

  system.stateVersion = "24.11";
}
