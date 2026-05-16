# SSH client configuration.
# Tracks ssh/config — keep in sync. The imperative installer symlinks ssh/config
# into ~/.ssh/config on non-NixOS hosts; this module mirrors its content for
# NixOS hosts via the home-manager programs.ssh schema.
#
# TODO: `StrictHostKeyChecking accept-new` is convenient for first-boot
# bootstrap but is weaker than pinning host keys. After Manifold is stable,
# pin known host keys for Manifold/Tensor/Hessian/Jacobian via
# programs.ssh.knownHosts or home.file.".ssh/known_hosts". Security hardening
# follow-up — not blocking.
{ vars, ... }:

let
  sshPort = vars.networking.sshPort;
  tailnet = vars.networking.tailnet;
in
{
  programs.ssh = {
    enable = true;
    includes = [ "~/.ssh/config.d/*.conf" ];

    matchBlocks = {
      "*" = {
        extraOptions = {
          PreferredAuthentications = "publickey";
          PubkeyAuthentication = "yes";
          IdentitiesOnly = "no";
          HashKnownHosts = "yes";
          UpdateHostKeys = "yes";
          StrictHostKeyChecking = "accept-new";
        };
        serverAliveInterval = 60;
        serverAliveCountMax = 3;
        forwardAgent = false;
      };

      # RPi servers use "ubuntu" user, not beegass
      "Jacobian Hessian" = {
        hostname = "%h.${tailnet}";
        user = "ubuntu";
        port = sshPort;
        forwardAgent = false;
        controlMaster = "auto";
        controlPath = "~/.ssh/cm-%C";
        controlPersist = "10m";
      };

      "Tensor Matrix Vector Manifold" = {
        hostname = "%h.${tailnet}";
        user = vars.username;
        port = sshPort;
        forwardAgent = false;
        controlMaster = "auto";
        controlPath = "~/.ssh/cm-%C";
        controlPersist = "10m";
      };

      "github.com github" = {
        hostname = "github.com";
        user = "git";
        port = 22;
        forwardAgent = false;
      };

      "mcopp" = {
        hostname = "mcopp.com";
        user = vars.username;
        port = 12211;
        requestTTY = true;
        forwardAgent = true;
        extraOptions = {
          StreamLocalBindUnlink = "yes";
          IdentitiesOnly = "no";
        };
      };
    };

    extraConfig = ''
      Match host mcopp exec "uname -s | grep -q Linux"
          RemoteForward /run/user/1001/gnupg/S.gpg-agent     /run/user/1000/gnupg/S.gpg-agent.extra
          RemoteForward /run/user/1001/gnupg/S.gpg-agent.ssh /run/user/1000/gnupg/S.gpg-agent.ssh

      Match host mcopp exec "uname -s | grep -q Darwin"
          RemoteForward /run/user/1001/gnupg/S.gpg-agent     /Users/beegass/.gnupg/S.gpg-agent.extra
          RemoteForward /run/user/1001/gnupg/S.gpg-agent.ssh /Users/beegass/.gnupg/S.gpg-agent.ssh
    '';
  };

  # Ensure the config.d directory exists for GPG agent SSH socket drop-in
  home.file.".ssh/config.d/.keep".text = "";
}
