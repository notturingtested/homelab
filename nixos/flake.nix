{
  description = "Homelab NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      hosts = {
        node1 = {};
      };

      mkHost = name: _: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit name; };
        modules = [
          disko.nixosModules.disko
          ./hosts/${name}/hardware.nix
          ./hosts/${name}/disk.nix
          ./modules/common.nix
          ./modules/tailscale.nix
          ./modules/github-runner.nix
        ];
      };
    in
    {
      nixosConfigurations = builtins.mapAttrs mkHost hosts;
    };
}
