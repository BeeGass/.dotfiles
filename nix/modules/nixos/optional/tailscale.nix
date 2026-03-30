# Tailscale -- WireGuard-based mesh VPN
#
# Connects this machine to the Tailscale network (tailnet) for secure
# peer-to-peer connectivity across all devices without port forwarding
# or firewall holes.
{ config, lib, pkgs, ... }:

{
  # Enable the Tailscale daemon (tailscaled). After the first boot, run
  # `sudo tailscale up` to authenticate and join the tailnet.
  services.tailscale.enable = true;

  networking.firewall = {
    # Tailscale's WireGuard port -- allows direct peer-to-peer connections.
    # Without this, connections may relay through Tailscale's DERP servers,
    # adding latency.
    allowedUDPPorts = [ 41641 ];

    # Trust the tailscale0 interface -- traffic arriving over the tailnet
    # bypasses firewall rules, allowing services (SSH, HTTP, etc.) to be
    # accessible to other tailnet devices without opening ports publicly.
    trustedInterfaces = [ "tailscale0" ];
  };
}
