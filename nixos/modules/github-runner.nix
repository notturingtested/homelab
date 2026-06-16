{ config, lib, pkgs, name, ... }:

{
  services.github-runners.${name} = {
    enable = true;
    url = "https://github.com/notturingtested";
    tokenFile = "/etc/github-runner/token";
    name = name;
    extraLabels = [ "nixos" "docker" ];
    extraPackages = with pkgs; [
      docker
      git
      curl
      nodejs
      python3
    ];
    serviceOverrides = {
      SupplementaryGroups = [ "docker" ];
    };
  };
}
