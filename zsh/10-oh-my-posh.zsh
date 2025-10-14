# ============================================================================
# Oh-My-Posh Configuration
# ============================================================================

export OH_MY_POSH_CONFIG="$HOME/.dotfiles/oh-my-posh/config.json"

# Fence against nounset inside OMP widgets
set +u
if command -v oh-my-posh &> /dev/null; then
  eval "$(oh-my-posh init zsh --config "$OH_MY_POSH_CONFIG")"
else
  echo "oh-my-posh not found. Install it to enable the prompt."
fi

# Convenience
enable-transient-prompt() { oh-my-posh toggle transient-prompt; }
reload-omp() { eval "$(oh-my-posh init zsh --config "$OH_MY_POSH_CONFIG")"; }

switch-theme() {
  local theme="$1"
  if [[ -z "$theme" ]]; then
    echo "Usage: switch-theme <theme-name>"
    if command -v brew &> /dev/null; then
      ls "$(brew --prefix oh-my-posh)"/themes/ | grep -E '\.omp\.(json|yaml|toml)$' | sed 's/\.[^.]*$//'
    else
      ls /usr/share/oh-my-posh/themes/ | grep -E '\.omp\.(json|yaml|toml)$' | sed 's/\.[^.]*$//'
    fi
    return 1
  fi
  local theme_path
  if command -v brew &> /dev/null; then
    theme_path="$(brew --prefix oh-my-posh)/themes/${theme}.omp.json"
  else
    theme_path="/usr/share/oh-my-posh/themes/${theme}.omp.json"
  fi
  if [[ -f "$theme_path" ]]; then
    export OH_MY_POSH_CONFIG="$theme_path"
    reload-omp
    echo "Switched to theme: $theme"
  else
    echo "Theme not found: $theme"
    return 1
  fi
}

edit-omp() { ${EDITOR:-nvim} "$OH_MY_POSH_CONFIG"; }
