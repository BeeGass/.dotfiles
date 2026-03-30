# SSH client configuration.
# Translates: ssh/config (55 lines)
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
      };

      "Tensor Matrix Vector Manifold" = {
        hostname = "%h.${tailnet}";
        user = vars.username;
        port = sshPort;
        forwardAgent = false;
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
    '';
  };

  # Ensure the config.d directory exists for GPG agent SSH socket drop-in
  home.file.".ssh/config.d/.keep".text = "";
}
