# Oh My Posh prompt configuration.
# Uses the existing config.json via symlink (complex Unicode/Nerd Font glyphs
# are error-prone to translate to Nix attrsets).
{ config, pkgs, ... }:
{
  home.packages = [ pkgs.oh-my-posh ];

  # Symlink the existing Oh My Posh config
  xdg.configFile."oh-my-posh/config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/oh-my-posh/config.json";

  # OMP init and convenience functions are in shell.nix initExtra
  # but the actual eval command needs to go there too:
  programs.zsh.initExtra = ''
    # Oh My Posh prompt
    export OH_MY_POSH_CONFIG="$HOME/.config/oh-my-posh/config.json"
    set +u
    if command -v oh-my-posh &> /dev/null; then
      eval "$(oh-my-posh init zsh --config "$OH_MY_POSH_CONFIG")"
    fi

    enable-transient-prompt() { oh-my-posh toggle transient-prompt; }
    reload-omp() { eval "$(oh-my-posh init zsh --config "$OH_MY_POSH_CONFIG")"; }
    edit-omp() { ''${EDITOR:-nvim} "$OH_MY_POSH_CONFIG"; }
  '';
}
