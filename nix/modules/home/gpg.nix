# GPG configuration.
# Translates: gnupg/gpg.conf + gnupg/linux-gpg-agent.conf
# Enhanced with security-hardened settings from feat/nix-flake-setup
#
# NOTE: source-of-truth duplication with ../../../gnupg/* pending refactor.
# Edits to ../../../gnupg/* will NOT take effect on NixOS until the
# dead-source-files refactor lands. For now, edit this file directly for GPG
# changes on NixOS; the ../../../gnupg/* files remain canonical for the
# imperative installer (macOS, RPi, Termux).
{ pkgs, lib, vars, ... }:
{
  programs.gpg = {
    enable = true;
    settings = {
      # Key display
      keyid-format = "0xlong";
      with-subkey-fingerprint = true;
      with-fingerprint = true;
      with-keygrip = true;
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";

      # Default key
      default-key = vars.gpgKeys.master;

      # Agent
      use-agent = true;
      auto-key-retrieve = true;
      auto-key-locate = "local,wkd,keyserver,clear";

      # Strong crypto preferences
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      charset = "utf-8";

      # Privacy hardening
      throw-keyids = true;    # Hide recipient key IDs in messages
      no-comments = true;     # Don't include comment packets
      no-emit-version = true; # Don't include version string
    };
  };

  # gpg-agent service (Linux only -- macOS manages gpg-agent differently)
  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    enableSshSupport = true;
    enableZshIntegration = true;
    pinentryPackage = pkgs.pinentry-gnome3;
    defaultCacheTtl = 1800;
    defaultCacheTtlSsh = 1800;
    maxCacheTtl = 7200;
    maxCacheTtlSsh = 7200;
  };
}
