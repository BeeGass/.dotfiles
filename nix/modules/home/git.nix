# Git configuration.
# Translates: git/gitconfig (69 lines)
#
# NOTE: source-of-truth duplication with ../../../git/gitconfig pending refactor.
# Edits to ../../../git/gitconfig will NOT take effect on NixOS until the
# dead-source-files refactor lands. For now, edit this file directly for git
# changes on NixOS; the ../../../git/gitconfig file remains canonical for the
# imperative installer (macOS, RPi, Termux).
{ config, pkgs, lib, vars, ... }:
{
  programs.git = {
    enable = true;
    userName = vars.fullName;
    userEmail = vars.email;

    signing = {
      key = vars.gpgKeys.signing;
      signByDefault = true;
    };

    delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
        side-by-side = false;
        line-numbers = true;
      };
    };

    extraConfig = {
      github.user = vars.githubUser;
      gpg.program = "gpg";
      push.autosetupremote = true;
      pull.rebase = false;
      init.defaultBranch = "main";

      merge = {
        conflictstyle = "diff3";
        tool = "vimdiff";
      };
      mergetool.keepBackup = false;
      "mergetool \"vimdiff\"".layout = "LOCAL,BASE,REMOTE / MERGED";

      core.editor = "nvim";
      diff.colorMoved = "default";
      interactive.diffFilter = "delta --color-only";
      # libsecret on Linux (NixOS), osxkeychain on macOS, cache as fallback
      credential.helper =
        if pkgs.stdenv.isDarwin then "osxkeychain"
        else if pkgs.stdenv.isLinux then "libsecret"
        else "cache --timeout=7200";
    };

    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      ci = "commit";
      unstage = "reset HEAD --";
      last = "log -1 HEAD";
      visual = "!gitk";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
    };

    includes = [{ path = "~/.gitconfig.local"; }];
  };

  # Provide the per-platform local override file referenced by programs.git.includes.
  # Without this, `git` warns on every invocation that ~/.gitconfig.local is missing.
  # On Linux: symlink to git/gitconfig.linux. On Darwin: git/gitconfig.macos.
  home.file.".gitconfig.local".source = config.lib.file.mkOutOfStoreSymlink (
    if pkgs.stdenv.isDarwin
    then "${config.home.homeDirectory}/.dotfiles/git/gitconfig.macos"
    else "${config.home.homeDirectory}/.dotfiles/git/gitconfig.linux"
  );

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
}
