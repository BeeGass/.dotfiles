# Networking: NetworkManager, firewall, Tailscale trust.
{ vars, ... }:
{
  # -- NetworkManager --
  networking.networkmanager.enable = true;

  # -- Firewall --
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ vars.networking.sshPort ];
    # tailscale0 trust is in optional/tailscale.nix (only for hosts with that role)
  };

  # Disable the NetworkManager-wait-online service.
  # It stalls boot when connectivity is slow or unavailable.
  systemd.services.NetworkManager-wait-online.enable = false;
}
