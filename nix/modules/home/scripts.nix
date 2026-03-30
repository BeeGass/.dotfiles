# Utility scripts symlinked to ~/.local/bin.
{ config, ... }:

let
  link = config.lib.file.mkOutOfStoreSymlink;
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  scriptDir = "${dotfiles}/scripts";
in
{
  home.file = {
    ".local/bin/doctor".source      = link "${scriptDir}/doctor.sh";
    ".local/bin/doctor.sh".source   = link "${scriptDir}/doctor.sh";
    ".local/bin/load-secrets".source    = link "${scriptDir}/load-secrets.sh";
    ".local/bin/load-secrets.sh".source = link "${scriptDir}/load-secrets.sh";
    ".local/bin/nf".source          = link "${scriptDir}/neofetch_random.sh";
    ".local/bin/setup_gpg_ssh.sh".source = link "${scriptDir}/setup_gpg_ssh.sh";
    ".local/bin/sfssh".source       = link "${scriptDir}/sfssh";
    ".local/bin/sftunnel".source    = link "${scriptDir}/sftunnel";
    ".local/bin/yk-gpg-refresh.sh".source = link "${scriptDir}/yk-gpg-refresh.sh";
    ".local/bin/yk-refresh".source  = link "${scriptDir}/yk-gpg-refresh.sh";
    ".local/bin/yk-lock".source     = link "${scriptDir}/yk-lock.sh";
    ".local/bin/yk-lock.sh".source  = link "${scriptDir}/yk-lock.sh";
    ".local/bin/yk-status".source   = link "${scriptDir}/yk-status.sh";
    ".local/bin/yk-status.sh".source = link "${scriptDir}/yk-status.sh";
  };
}
