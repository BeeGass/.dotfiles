#!/usr/bin/env bash
set -euo pipefail
pass(){ printf "✓ %s\n" "$*"; }
fail(){ printf "✗ %s\n" "$*"; exit 1; }

# 1) Shell & PATH
command -v zsh >/dev/null || fail "zsh missing"
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || fail "~/.local/bin not in PATH"; pass "PATH ok"

# 2) Editor
command -v nvim >/dev/null || fail "neovim missing"
[ -f "$HOME/.config/nvim/init.vim" ] || fail "~/.config/nvim/init.vim symlink missing"; pass "Neovim wired to vimrc"

# 3) Prompt
command -v oh-my-posh >/dev/null || fail "oh-my-posh missing"
# crude glyph check: JetBrainsMono Nerd present?
fc-list | grep -qi 'JetBrains.*Nerd' || echo "! Nerd Font not detected; prompt icons may be broken"
pass "Prompt stack present"

# 4) Git creds
helper="$(git config --global credential.helper || true)"
case "$(uname -s)" in
  Darwin) [[ "$helper" == manager* ]] || echo "! credential.helper not 'manager' on macOS";;
  Linux)
    if [[ -n "${TERMUX_VERSION-}" ]]; then [[ "$helper" == cache* ]] || echo "! credential.helper not 'cache' on Termux"
    else [[ "$helper" == libsecret* ]] || echo "! credential.helper not 'libsecret' on Ubuntu"
    fi
    ;;
esac
pass "Git helper set (check warnings above)"

# 5) tmux
command -v tmux >/dev/null || fail "tmux missing"
tmux -V >/dev/null || fail "tmux not runnable"; pass "tmux ok"

# 6) SF Compute CLI
if ! command -v sf >/dev/null 2>&1; then
  echo "! sf CLI missing; install SF Compute CLI to use sfssh/sftunnel"
else
  pass "SF Compute CLI present"
fi

echo "All checks completed."
