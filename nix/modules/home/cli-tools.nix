# CLI tools and their configurations.
# Replaces tool integration from zsh/80-tools.zsh and packages from install/ubuntu-install.sh.
{ pkgs, lib, ... }:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [ "--height" "40%" "--layout=reverse" "--border" ];
    defaultCommand = "rg --files --hidden --follow --glob '!.git/*'";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    fileWidgetCommand = "rg --files --hidden --follow --glob '!.git/*'";
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      pager = "less -FR";
    };
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = false; # Custom aliases in shell.nix
    icons = "auto";
    git = true;
    extraOptions = [ "--group-directories-first" "--classify" ];
  };

  programs.ripgrep = {
    enable = true;
    arguments = [
      "--smart-case"
      "--hidden"
      "--glob=!.git/*"
    ];
  };

  # direnv + nix-direnv: auto-activate per-project dev shells
  # Drop a .envrc with `use flake` in any project and nix develop activates on cd
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Enable fontconfig for font discovery
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    fd
    jq
    curl
    wget
    unzip
    tree
    htop
    w3m
    chafa
    fastfetch  # neofetch successor (neofetch is archived upstream)
    pfetch
    shellcheck
    shfmt
    delta
    ncdu
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    iotop       # Linux-only (requires /proc)
    wl-clipboard # Wayland clipboard (Linux-only)
  ];

  # Neofetch config
  xdg.configFile."neofetch/config.conf".source = ../../../neofetch/desktop-neofetch.conf;
}
