# BeeGass Dotfiles

Streamlined, idempotent setup for shells, editors, terminals, fonts, SSH/GPG, and daily CLI tooling across macOS, Ubuntu/Linux, NixOS, Raspberry Pi, HPC clusters, and Termux. Uses clean symlinks, keeps backups, and stays out of your secrets.

---

## TL;DR (Quickstart)

**Bootstrap (recommended for bare machines)**

```bash
# Installs git + just, clones repo, runs `just install`
curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/bootstrap.sh | bash
```

**Using `just` (if repo is already cloned)**

```bash
git clone https://github.com/BeeGass/.dotfiles ~/.dotfiles
cd ~/.dotfiles
just install
```

**Manual (no `just` required)**

```bash
git clone https://github.com/BeeGass/.dotfiles ~/.dotfiles
~/.dotfiles/install/install.sh
```

> Re-run the installer any time; it's safe. Existing non-symlink files are timestamp-backed up.

---

## Supported platforms

* **macOS** (Homebrew-based)
* **Ubuntu/Linux** (apt; Kitty + Ghostty)
* **Raspberry Pi** (apt; headless-friendly)
* **HPC clusters** (no sudo; user-space tools only)
* **NixOS** (snippet provided; minor manual steps)
* **Termux (Android)** (pkg; ergonomic mobile defaults)

---

## Task runner (`just`)

[`just`](https://github.com/casey/just) is the primary interface for managing the dotfiles. All recipes are listed with `just --list`.

### Install recipes

| Recipe | Description |
|--------|-------------|
| `just install` | Auto-detect platform and run main installer |
| `just install-ubuntu` | Ubuntu/Debian desktop |
| `just install-macos` | macOS (Homebrew) |
| `just install-rpi` | Raspberry Pi |
| `just install-hpc` | HPC cluster (no sudo, user-space only) |

### Refresh recipes

| Recipe | Description |
|--------|-------------|
| `just refresh` | Full idempotent refresh |
| `just refresh-fast` | Skip slow operations (Python installs, tmux updates) |
| `just refresh-dry` | Preview changes without applying |
| `just refresh-python` | Refresh only the Python/uv section |
| `just refresh-node` | Refresh only the Node.js section |
| `just refresh --only <section>` | Run a specific section |

Available sections: `path`, `local`, `directories`, `cleanup`, `backups`, `omp`, `zsh`, `python`, `node`, `tmux`, `ssh`, `snap`, `claude`, `gemini`, `opencode`, `flatpak`, `tailscale`, `sf`, `git`, `fonts`

### Utility recipes

| Recipe | Description |
|--------|-------------|
| `just clean` | Remove all dotfiles-managed state (with confirmation) |
| `just clean --dry-run` | Preview what clean would remove |
| `just doctor` | Run health checks |
| `just update-omp` | Update Oh My Posh |
| `just update-python` | Update Python environment |
| `just update-node` | Update Node.js environment |
| `just update-tmux` | Update tmux plugins |
| `just clean-backups` | Remove old `*.backup.*` files |

### Common flags

All install and refresh scripts accept these flags:

| Flag | Description |
|------|-------------|
| `--no-sudo` | Skip commands requiring sudo |
| `--dry-run` | Preview changes without applying |
| `--fast` | Skip slow operations |
| `-v`, `--verbose` | Increase verbosity |

Every script still runs standalone without `just` installed (e.g. `bash install/refresh.sh --only python`).

---

## What the installer does

1. **Detects OS** and writes flags to `${XDG_STATE_HOME:-~/.local/state}/dotfiles/flags` and an OS snapshot to `os.env`.

2. **Symlinks config**

   * `~/.zshenv` (early), `~/.zshrc`, `~/.gitconfig`, Vim/Neovim, tmux, ssh, kitty/wezterm/ghostty.
   * Binaries in `~/.dotfiles/scripts/*` linked into `~/.local/bin` (both with and without `.sh`).
   * Convenience commands: `dots-install`, `dots-refresh`, `dots-bootstrap`, `dots-clean`.
   * Backs up any existing non-symlink targets as `*.backup.YYYYMMDD_HHMMSS`.

3. **Installs platform packages**

   * macOS: Homebrew + common CLIs, Kitty/Ghostty.
   * Ubuntu: apt CLIs, Kitty, Ghostty (or Kitty fallback).
   * Raspberry Pi: apt CLIs, headless tools.
   * HPC: user-space only (uv, cargo tools, fzf, oh-my-posh).
   * NixOS: declarative snippet to add packages.
   * Termux: pkg CLIs, Zsh plugins.

4. **Developer tooling**

   * **oh-my-posh** prompt + theme at `~/.config/oh-my-posh/config.json`.
   * **uv** (Python launcher/PM); installs CPython **3.11-3.14**; common tools (`ruff`, `mypy`, `pytest`, `pre-commit`, `python-lsp-server`).
   * **Node** via `nvm` (latest LTS), plus `@google/gemini-cli`, `typescript`, `typescript-language-server`.
   * **Optional**: tailscale, SF Compute CLI if available.

5. **Fonts & terminals**

   * JetBrains Mono Nerd Font (platform-appropriate install).
   * Optional Google Sans / Google Sans Mono (Ubuntu installs via SSH cloning; see notes).
   * Kitty, Ghostty, WezTerm configured; right-click paste; tmux autostart; 80% opacity; F11 fullscreen.

6. **GPG + SSH**

   * `scripts/setup_gpg_ssh.sh` links `gnupg/*` configs per-OS, wires **gpg-agent as SSH agent**, exports SSH pubkey from your auth subkey, and drops a `~/.ssh/config.d/10-gpg-agent.conf` with `IdentityAgent`.
   * Helpers: `yk-status` (diagnostics), `yk-lock` (clear pin caches), `sfssh`/`sftunnel` (SF Compute wrappers).

7. **Quality of life**

   * `scripts/doctor.sh` sanity checks.
   * `scripts/neofetch_random.sh` aliasable to `nf` (random image, backend auto-pick); optional image pack fetched with `uvx gdown`.
   * `systemd --user` picom service on X11 with app-opacity rules.

---

## Safety & design choices

* **Idempotent**: re-running is fine; safe backups for pre-existing files.
* **No secrets in repo**: machine-local, private overrides live in `zsh/90-local.zsh` (auto-created, `0600`).
* **Credential helpers**: macOS: `osxkeychain`/`git-credential-manager`; Ubuntu: `libsecret`; HPC/Termux: `cache`.
* **Termux ergonomics**: ESC/back mapping, extra keys, Nerd font, Zsh plugins.
* **Shared library**: all scripts source `install/lib.sh` for logging, helpers, and OS detection -- no duplicated code.

---

## Install, update, refresh

### First install

Use the **bootstrap one-liner**, `just install`, or clone + run `install/install.sh`. The script will:

* write OS flags/env snapshot
* symlink configs
* install OS packages + core CLIs
* set up dev tools (uv, node, prompt)
* configure Git identity + credential helper
* bootstrap GPG/SSH if `gpg` exists

Open a new shell or `source ~/.zshrc`.

### Refresh an existing machine

```bash
just refresh          # or: ~/.dotfiles/install/refresh.sh
just refresh-fast     # skip slow operations
just refresh-dry      # preview only
```

* Ensures `~/.zshrc` loads repo config (no-op if symlinked)
* (Re)installs/updates oh-my-posh, Zsh plugins, Node CLIs, `uv`, CPython
* Scaffolds a minimal prompt config if missing

### Health check

```bash
just doctor           # or: ~/.dotfiles/scripts/doctor.sh
```

### Clean (undo all changes)

```bash
just clean --dry-run  # preview what would be removed
just clean            # remove all dotfiles-managed state (prompts for confirmation)
```

The clean script:
* Removes all symlinks pointing into the dotfiles tree
* Removes shell modifications (loader stubs, PATH exports)
* Removes OS flags, plugins, fonts, desktop entries
* **Keeps** git identity and SSH config by default (use `--clean-git` / `--clean-ssh` to remove)
* Supports `--keep-tools` to preserve user-space tools (uv, cargo, nvm, etc.)

After cleaning, run the correct installer for your platform.

---

## HPC cluster setup

For shared clusters without sudo access:

```bash
just install-hpc      # or: bash install/hpc-install.sh
```

This installs everything to `~/.local/bin` and `~/.cargo/bin`:
* Detects zsh via environment modules (`module load zsh`)
* Falls back to `.bash_profile` exec stub if `chsh` is denied
* Installs uv + Python, oh-my-posh, Rust toolchain, cargo tools (bat, fd, rg, delta, eza), fzf
* Creates an HPC-specific `90-local.zsh` with Slurm aliases and module stubs

---

## GPG + SSH quickstart

```bash
# Regenerate imports and exports; wire gpg-agent -> SSH; optional: set Git signing
~/.dotfiles/scripts/setup_gpg_ssh.sh --regen --git

# Verify sockets, keys, and card
yk-status

# Force a lock (clear caches)
yk-lock
```

**Notes**

* Per-OS agent config is symlinked from `gnupg/*-gpg-agent.conf`.
* Shell snippet appended to `zsh/90-local.zsh` ensures `GPG_TTY` + SSH agent wiring on login.
* SSH config includes `Include ~/.ssh/config.d/*.conf` and ships a `10-gpg-agent.conf` drop-in.

---

## Fonts & Fontconfig

* **JetBrains Mono Nerd**: installed per-platform for glyphs used by the prompt.
* **Google Sans / Google Sans Mono**: optional, **installed via SSH cloning** on Ubuntu:

  * `git@github.com:mehant-kr/Google-Sans-Mono.git`
  * `git@github.com:hprobotic/Google-Sans-Font.git`
  * If you don't have GitHub SSH access on that machine, the step is skipped.
* `fontconfig/30-google-sans-mono-mono.conf` sets `spacing=100` to force mono metrics for Google Sans Mono.

---

## Terminals

### Kitty (Linux/macOS)

* 80% opacity; right-click paste; `shell tmux -u new-session -A -s main` autostart.
* Fonts respect Fontconfig fallbacks: Google Sans Mono, JetBrains Mono, SF Mono, Symbols Nerd Mono.
* Key: `F11` toggles fullscreen.

### Ghostty

* Same theme: `background=000000`, `foreground=ffffff`, `background-opacity=0.80`.
* Titlebar hidden on macOS; client decorations on Linux; tmux autostart; `F11` fullscreen.

### WezTerm

* Config present; shares the same font and opacity design.

---

## tmux (prefix = **Ctrl+Space**)

| Action                      | Keys                                                    |       |
| --------------------------- | ------------------------------------------------------- | ----- |
| Split vertical / horizontal | `Ctrl+Space` `                                          | `/`-` |
| Navigate panes              | `Ctrl+Space` + arrows (or `Alt` + arrows **no prefix**) |       |
| Resize panes                | `Ctrl+Space` + `Shift` + arrows                         |       |
| Copy mode                   | `Ctrl+Space` `[` then `v` to select, `y` to copy        |       |
| Zoom pane                   | `Ctrl+Space` `z` (or `Alt` `z`)                         |       |
| New window / switch         | `Ctrl+Space` `c` / `n` `p` `0..9`                       |       |
| Reload config               | `Ctrl+Space` `r`                                        |       |

Plugins via TPM are declared at the bottom; first-run will auto-install TPM.

---

## Scripts (selected)

| Script                              | What it does                                                                                      |
| ----------------------------------- | ------------------------------------------------------------------------------------------------- |
| `install/install.sh`                | Main installer; supports `--remote` when piped from curl.                                         |
| `install/bootstrap.sh`              | Curl-able bootstrap: installs git + just, clones repo, runs `just install`.                       |
| `install/clean.sh`                  | Removes all dotfiles-managed symlinks, configs, and tools (with confirmation).                    |
| `install/refresh.sh`                | Idempotent refresh; dispatches to modular section scripts in `install/sections/`.                 |
| `install/lib.sh`                    | Shared library: logging, OS detection, helpers. Sourced by all install scripts.                   |
| `install/ubuntu-install.sh`         | apt packages; Kitty install + desktop entries; Ghostty; fonts; picom service.                     |
| `install/macos-install.sh`          | Homebrew packages; Kitty CLI wiring; macOS applet "Open Here in Kitty".                           |
| `install/rpi-install.sh`            | Raspberry Pi setup; apt packages; SSH server hardening.                                           |
| `install/hpc-install.sh`            | HPC cluster setup; no sudo; user-space tools to `~/.local/bin`.                                   |
| `install/termux-install.sh`         | pkg packages; Zsh plugins; Nerd font; Termux ergonomics.                                          |
| `install/nixos-install.sh`          | NixOS snippet; guidance.                                                                          |
| `scripts/setup_gpg_ssh.sh`          | Wire gpg-agent -> SSH; per-OS agent conf; export SSH pub; login snippet; optional git signing.     |
| `scripts/yk-status.sh`              | Inspect sockets, keys, sshcontrol, and optional remote test.                                      |
| `scripts/yk-lock.sh`                | Clear agent caches; restart scdaemon/gpg-agent.                                                   |
| `scripts/neofetch_random.sh`        | Smart backend choice; draws random image alongside neofetch.                                      |
| `scripts/doctor.sh`                 | Health checks for PATH, nvim, prompt, git helper, tmux, SF CLI.                                   |
| `scripts/repo_to_text`              | Emit a text snapshot of repo structure/files with a globby ignore.                                |
| `scripts/sfssh`, `scripts/sftunnel` | Convenience wrappers around SF Compute CLI.                                                       |

> All scripts are linked into `~/.local/bin` (both with and without `.sh`).

---

## Picom (Linux/X11)

* Config at `picom/picom.conf` enforces app-specific opacity (kitty/wezterm at 80%).
* `systemd --user` unit `systemd/user/picom.service` is linked and **ExecCondition**-gated to X11.

---

## Directory layout (abridged)

```
.dotfiles/
  justfile                           # Task runner entry point
  install/
    lib.sh                           # Shared library (logging, helpers, OS detect)
    install.sh                       # Main installer
    bootstrap.sh                     # Curl-able bootstrap
    clean.sh                         # Undo all changes
    refresh.sh                       # Idempotent refresh (dispatches to sections/)
    ubuntu-install.sh                # Ubuntu/Debian
    macos-install.sh                 # macOS
    rpi-install.sh                   # Raspberry Pi
    hpc-install.sh                   # HPC clusters
    termux-install.sh                # Termux (Android)
    nixos-install.sh                 # NixOS
    sections/                        # Modular refresh sections
      path.sh  local.sh  directories.sh  cleanup.sh  backups.sh
      omp.sh   zsh.sh    python.sh       node.sh     tmux.sh
      ssh.sh   snap.sh   claude.sh       gemini.sh   opencode.sh
      flatpak.sh  tailscale.sh  sf.sh    git.sh      fonts.sh
  fontconfig/30-google-sans-mono-mono.conf
  ghostty/config         kitty/kitty.conf      wezterm/wezterm.lua
  git/gitconfig          ssh/{config,sshd_config_secure}
  gnupg/*.conf           systemd/user/picom.service
  scripts/*              tmux/tmux.conf
  neofetch/*.conf        oh-my-posh/config.json
  termux/*               vim/{vimrc,pyproject.toml}
  zsh/*                  .pre-commit-config.yaml
```

---

## Uninstall / rollback

Use the clean script to remove all dotfiles-managed state:

```bash
just clean --dry-run   # preview first
just clean             # prompts for confirmation
```

Options:
* `--keep-tools` -- keep uv, cargo, nvm, oh-my-posh, fzf
* `--clean-git` -- also remove git identity (kept by default)
* `--clean-ssh` -- also remove SSH config (kept by default)
* `--no-sudo` -- skip system-level removals
* `--dry-run` -- preview without changes

Or manually: remove symlinks you don't want under `~`, or delete `~/.dotfiles` + hand-pick from timestamped backups.

---

## FAQ / Notes

* **Where do machine-local secrets go?** `zsh/90-local.zsh` (auto-created; `0600`).
* **Why Google Sans?** Optional aesthetics; Fontconfig rule ensures mono spacing for terminals.
* **Can I skip fonts?** Yes -- Ubuntu task will skip Google Sans if SSH cloning fails.
* **What does `doctor.sh` warn about?** It checks presence of core tools and advises on credential helpers and Nerd Fonts.
* **Do I need `just` installed?** No -- all scripts run standalone. `just` is the preferred interface but not a hard dependency.
* **How do I undo a wrong install?** Run `just clean` (or `bash install/clean.sh`), then run the correct installer.

---

## License

No license declared yet. Add one if you plan to share/reuse widely.
