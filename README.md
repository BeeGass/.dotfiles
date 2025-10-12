# Dotfiles

Personal dotfiles for macOS, Linux, and Termux. Modular ZSH, modern CLI tools, a fast prompt, sane tmux defaults, and optional WezTerm integration.

## Features

- **Oh-My-Posh** prompt (powerlevel10k_modern-based), fast and minimal
- **Modular ZSH**: clean layers for env, plugins, aliases, keybinds
- **Modern CLI**: fzf, eza, bat, ripgrep, delta, plus handy scripts
- **UV** for Python project/env management
- **GPG/YubiKey**: SSH via gpg-agent and quick setup docs
- **Smart cd** helpers & bookmarks
- **Google Sans Mono** primary font + Nerd Font fallback for icons
- **WezTerm** config (optional): GPU-accelerated, tmux-first workflow
- **Tmux**: vim-style navigation, mouse support, tidy statusline
- **Termux** support: sane defaults on Android, with Termux UI tweaks
- **AI helpers**: ready-to-use Claude and Gemini workflows
- **Docs**: SSH quick refs, external access, YubiKey setup

---

## Quick Install

### One-liner (auto-detects OS and runs the right installer)

On Termux, also install `bash`, `curl`, and `wget` first:
```bash
pkg install -y bash curl wget  # Termux only
````

Using curl:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/install.sh) -- --remote
````

```bash
curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/install.sh | bash -s -- --remote
```

```bash
bash -lc 'set -e
D="$HOME/.dotfiles"
if ! command -v git >/dev/null 2>&1; then pkg install -y git curl tar >/dev/null; fi
if [ -d "$D/.git" ]; then git -C "$D" pull --ff-only; else git clone --depth=1 https://github.com/BeeGass/.dotfiles "$D"; fi
exec bash "$D/install/install.sh" --remote
'
```

Using wget:

```bash
wget -qO- https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/install.sh | bash -s -- --remote
```

### Per-platform installers

* **macOS**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/macos-install.sh)
```
* **Ubuntu/Debian**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/ubuntu-install.sh)
```
* **NixOS**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/nixos-install.sh)
```
* **Termux (Android)**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/termux-install.sh)
```

### Manual (traditional)

```bash
git clone https://github.com/BeeGass/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./install/install.sh
```

---

## Prerequisites

* ZSH
* Git
* A terminal with 24-bit color (WezTerm, iTerm2, Alacritty, etc.)
* Optional: WezTerm for GPU-accelerated rendering

---

## Directory Structure

```
.
├── claude
│   ├── claude-functions.zsh
│   ├── CLAUDE.md
│   ├── commands
│   │   ├── commit.md
│   │   └── prime.md
│   ├── PERMISSIONS.md
│   ├── PROJECT_CLAUDE_TEMPLATE.md
│   ├── settings.json
│   ├── settings.local.json
│   ├── TOOLS.md
│   └── WORKFLOW.md
├── docs
│   ├── ssh-external-access.md
│   ├── ssh-quick-reference.md
│   └── ssh-yubikey-setup.md
├── gemini
│   └── GEMINI.md
├── git
│   ├── gitconfig
│   └── gitconfig.local
├── install
│   ├── install.sh
│   ├── macos-install.sh
│   ├── nixos-install.sh
│   ├── refresh.sh
│   ├── termux-install.sh
│   └── ubuntu-install.sh
├── oh-my-posh
│   ├── config.json
│   └── README.md
├── README.md
├── scripts
│   └── repo_to_text
├── ssh
│   ├── config
│   └── sshd_config_secure
├── termux
│   ├── colors.properties
│   └── termux.properties
├── tmux
│   ├── README.md
│   └── tmux.conf
├── vim
│   ├── main.py
│   ├── pyproject.toml
│   ├── README.md
│   └── vimrc
├── wezterm
│   └── wezterm.lua
└── zsh
    ├── 00-init.zsh
    ├── 10-oh-my-posh.zsh
    ├── 20-environment.zsh
    ├── 30-plugins.zsh
    ├── 40-aliases.zsh
    ├── 50-functions.zsh
    ├── 60-claude.zsh
    ├── 60-completions.zsh
    ├── 70-keybindings.zsh
    ├── 80-tools.zsh
    ├── 90-local.zsh
    └── zshrc
```

---

## Fonts

Install **Google Sans Mono** + a Nerd Font for icons.

* **macOS**: copy `.ttf` files to `~/Library/Fonts/`
* **Linux**: copy `.ttf` files to `~/.local/share/fonts/` and run `fc-cache -f -v`

---

## WezTerm (optional but recommended)

The repo ships a minimal WezTerm config tuned for tmux-first workflows:

* Color scheme: **Builtin Dark**
* Background opacity: **0.80**
* Decorations: **RESIZE** (toggle title bar with **F11**)
* Font: **Google Sans Mono** with fallbacks, size 10.0
* Performance: OpenGL front end, 120 FPS, large scrollback
* Default program: auto-start `tmux` (`main` session)

---

## Termux (Android)

Termux gets sensible defaults:

* Installs core CLI tools and ZSH
* Applies `termux/termux.properties` and `termux/colors.properties`

To reapply properties:

```bash
termux-reload-settings
```

---

## Tmux

Vim-style navigation, mouse support, and a compact statusline. Prefix is `Ctrl+a`.

Quick reference:

* `tmux` — start (or attach to) a session
* `Ctrl+a c` — new window
* `Ctrl+a |` — split vertically
* `Ctrl+a -` — split horizontally
* `Ctrl+a h/j/k/l` — move between panes
* `Ctrl+a d` — detach

## Shell Goodies

### Directory Bookmarks

* `cd ~pm` → `~/Documents/Coding/PM`
* `cd ~ludo` → `~/Documents/Coding/Ludo`
* `cd ~dots` → `~/.dotfiles`
* `cd ~projects` → `~/Projects`
* `cd ~downloads` → `~/Downloads`
* `cd ~docs` → `~/Documents`

### Scripts

* `repo_to_text` — flatten a repository into a text snapshot
* All `scripts/*` are symlinked to `~/.local/bin/`

### Oh-My-Posh helpers

* `edit-omp`, `reload-omp`, `switch-theme <name>`

### Python/UV helpers

* `uvnew <project> [version]`, `uvsetup`, `uvupgrade`, `mkuv`, `activateuv`

### Git helpers

* `allbranches` — track all remotes locally
* `config` — manage dotfiles via a bare repo

---

## Configuration Tips

### iTerm2

1. Preferences → **Profiles → Text**
2. Font: **Google Sans Mono** (13–14pt)
3. Non-ASCII Font: **Symbols Nerd Font Mono**

### WezTerm shortcuts

* `F11` — toggle title bar
* tmux handles the rest of your splits/keys

---

## Maintenance

Verify everything with:

```bash
~/.dotfiles/install/refresh.sh
```

Checks symlinks, PATH, required tools, fonts, ZSH plugins, and prompt/theme health with clear ✓/⚠/✗ output.

---

## Troubleshooting

**Icons missing**
Ensure a Nerd Font fallback is configured in your terminal.

**Command not found**
Re-run the installer: `~/.dotfiles/install/install.sh`

**Performance**
Disable git status for huge repos in your prompt, or enable a transient prompt.

---

## Security Notes

* `gitconfig` avoids storing secrets; use credential helpers
* GPG signing enabled by default
* Private/local overrides are git-ignored

---

## License

MIT. Fork, remix, enjoy.

---

## Acknowledgments

* [Oh-My-Posh](https://ohmyposh.dev/)
* [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
* The open-source tool authors who make terminals fun
