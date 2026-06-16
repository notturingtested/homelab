{ config, lib, pkgs, name, role, ... }:

let
  isServer = role == "server";
in
{
  services.k3s = {
    enable = true;
    role = role;
    # The server node's token is shared with agents for joining
    tokenFile = "/etc/k3s/token";
    # Agents need to know the server address
    serverAddr = lib.mkIf (!isServer) "https://node1:6443";
    extraFlags = lib.concatStringsSep " " (
      (lib.optionals isServer [
        "--disable=traefik"           # We'll use our own ingress
        "--disable=servicelb"         # Use tailscale or metallb
        "--tls-san=node1"             # Add tailscale hostname to cert SANs
        "--tls-san=node1.your-tailnet.ts.net"  # TODO: update
      ])
      ++ [
        "--node-name=${name}"
      ]
    );
  };

  # Open k3s ports for cluster communication
  networking.firewall.allowedTCPPorts = lib.mkIf isServer [ 6443 ];
  networking.firewall.allowedTCPPortRanges = [
    { from = 2379; to = 2380; }  # etcd (server only, but harmless)
  ];
  networking.firewall.allowedUDPPorts = [
    8472  # flannel VXLAN
    51820 # flannel wireguard
  ];
}
