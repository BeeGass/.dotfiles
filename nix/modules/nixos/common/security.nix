# Security: GPG agent, YubiKey, Polkit, password store.
{ pkgs, ... }:
{
  # -- Smartcard daemon (required for YubiKey GPG) --
  services.pcscd.enable = true;

  # NOTE: gpg-agent is managed by home-manager (home/gpg.nix), NOT here.
  # Having both system-level and home-manager gpg-agent causes conflicts.
  # System-level only provides pcscd, udev rules, and packages.

  # -- YubiKey udev rules --
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # -- Polkit (required by many desktop services) --
  security.polkit.enable = true;

  # -- Security-related system packages --
  environment.systemPackages = with pkgs; [
    gnupg
    yubikey-personalization
    yubico-piv-tool
    pcsctools
    pinentry-gnome3
    pass
    pass-otp
  ];
}
