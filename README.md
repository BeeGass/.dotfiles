# BeeGass Dotfiles

Streamlined, idempotent setup for shells, editors, terminals, fonts, SSH/GPG, and daily CLI tooling across macOS · Ubuntu/Linux · NixOS · Termux. Uses clean symlinks, keeps backups, and stays out of your secrets.

---

## TL;DR (Quickstart)

**Remote one‑liner (safe, idempotent)**

```bash
# Clones to ~/.dotfiles, then runs the installer
curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install/install.sh | bash -s -- --remote
```

**Manual**

```bash
git clone https://github.com/BeeGass/.dotfiles ~/.dotfiles
~/.dotfiles/install/install.sh
```

> Re-run the installer any time; it’s safe. Existing non-symlink files are timestamp‑backed up.

---

## Supported platforms

* **macOS** (Homebrew-based)
* **Ubuntu/Linux** (apt; Kitty + Ghostty when supported)
* **NixOS** (snippet provided; minor manual steps)
* **Termux (Android)** (pkg; ergonomic mobile defaults)

---

## What the installer does

1. **Detects OS** → writes flags to `${XDG_STATE_HOME:-~/.local/state}/dotfiles/flags` and an OS snapshot to `${XDG_STATE_HOME:-~/.local/state}/dotfiles/os.env`.

2. **Symlinks config**

   * `~/.zshenv` (early), `~/.zshrc`, `~/.gitconfig`, Vim/Neovim, tmux, ssh, kitty/wezterm/ghostty.
   * Binaries in `~/.dotfiles/scripts/*` → linked into `~/.local/bin` (both with and without `.sh`).
   * Backs up any existing non-symlink targets as `*.backup.YYYYMMDD_HHMMSS`.

3. **Installs platform packages**

   * macOS: Homebrew + common CLIs, Kitty/Ghostty.
   * Ubuntu: apt CLIs, Kitty, Ghostty (or Kitty fallback).
   * NixOS: declarative snippet to add packages.
   * Termux: pkg CLIs, Zsh plugins.

4. **Developer tooling**

   * **oh-my-posh** prompt + theme at `~/.config/oh-my-posh/config.json`.
   * **uv** (Python launcher/PM); installs CPython **3.11** and **3.12**; common Python tools (`ruff`, `mypy`, `pytest`, `pre-commit`, `python-lsp-server`).
   * **Node** via `nvm` (latest LTS), plus `@anthropic-ai/claude-code`, `@google/gemini-cli`, TS + LSP.
   * **Optional**: tailscale, SF Compute CLI if available.

5. **Fonts & terminals**

   * JetBrains Mono Nerd Font (platform-appropriate install).
   * Optional Google Sans / Google Sans Mono (Ubuntu task installs via **SSH** cloning; see notes).
   * Kitty, Ghostty, WezTerm configured; right‑click paste; tmux autostart; 80% opacity; F11 fullscreen.

6. **GPG + SSH**

   * `scripts/setup_gpg_ssh.sh` links `gnupg/*` configs per‑OS, wires **gpg-agent as SSH agent**, exports SSH pubkey from your auth subkey, and drops a `~/.ssh/config.d/10-gpg-agent.conf` with `IdentityAgent`.
   * Helpers: `yk-status` (diagnostics), `yk-lock` (clear pin caches), `sfssh`/`sftunnel` (SF Compute wrappers).

7. **Quality of life**

   * `scripts/doctor.sh` sanity checks.
   * `scripts/neofetch_random.sh` aliasable to `nf` (random image, backend auto-pick); optional image pack fetched with `uvx gdown`.
   * `systemd --user` picom service on X11 with app‑opacity rules.

---

## Safety & design choices

* **Idempotent**: re-running is fine; safe backups for pre-existing files.
* **No secrets in repo**: machine-local, private overrides live in `zsh/90-local.zsh` (auto-created, `0600`).
* **Credential helpers**: macOS→`osxkeychain`/`git-credential-manager`; Ubuntu→`libsecret`; Termux→`cache`.
* **Termux ergonomics**: ESC/back mapping, extra keys, Nerd font, Zsh plugins.

---

## Install, update, refresh

### First install

Use the **one-liner** or clone + run `install/install.sh`. The script will:

* write OS flags/env snapshot
* symlink configs
* install OS packages + core CLIs
* set up dev tools (uv, node, prompt)
* configure Git identity + credential helper
* bootstrap GPG/SSH if `gpg` exists

Open a new shell or `source ~/.zshrc`.

### Refresh an existing machine

```bash
~/.dotfiles/install/refresh.sh
```

* Ensures `~/.zshrc` loads repo config (no-op if symlinked)
* (Re)installs/updates oh‑my‑posh, Zsh plugins, Node CLIs, `uv`, CPython 3.11/3.12
* Scaffolds a minimal prompt config if missing

### Health check

```bash
~/.dotfiles/scripts/doctor.sh
```

---

## GPG + SSH quickstart

```bash
# Regenerate imports and exports; wire gpg-agent → SSH; optional: set Git signing
~/.dotfiles/scripts/setup_gpg_ssh.sh --regen --git

# Verify sockets, keys, and card
yk-status

# Force a lock (clear caches)
yk-lock
```

**Notes**

* Per‑OS agent config is symlinked from `gnupg/*-gpg-agent.conf`.
* Shell snippet appended to `zsh/90-local.zsh` ensures `GPG_TTY` + SSH agent wiring on login.
* SSH config includes `Include ~/.ssh/config.d/*.conf` and ships a `10-gpg-agent.conf` drop‑in.

---

## Fonts & Fontconfig

* **JetBrains Mono Nerd**: installed per-platform for glyphs used by the prompt.
* **Google Sans / Google Sans Mono**: optional, **installed via SSH cloning** on Ubuntu:

  * `git@github.com:mehant-kr/Google-Sans-Mono.git`
  * `git@github.com:hprobotic/Google-Sans-Font.git`
  * If you don’t have GitHub SSH access on that machine, the step is skipped.
* `fontconfig/30-google-sans-mono-mono.conf` sets `spacing=100` to force mono metrics for Google Sans Mono.

---

## Terminals

### Kitty (Linux/macOS)

* 80% opacity; right‑click paste; `shell tmux -u new-session -A -s main` autostart.
* Fonts respect Fontconfig fallbacks: Google Sans Mono → JetBrains Mono → SF Mono → Symbols Nerd Mono.
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
| Copy mode                   | `Ctrl+Space` `[` → `v` to select, `y` to copy           |       |
| Zoom pane                   | `Ctrl+Space` `z` (or `Alt` `z`)                         |       |
| New window / switch         | `Ctrl+Space` `c` / `n` `p` `0..9`                       |       |
| Reload config               | `Ctrl+Space` `r`                                        |       |

Plugins via TPM are declared at the bottom; first-run will auto-install TPM.

---

## Scripts (selected)

| Script                              | What it does                                                                                      |
| ----------------------------------- | ------------------------------------------------------------------------------------------------- |
| `install/install.sh`                | Main installer; supports `--remote` when piped from curl.                                         |
| `install/macos-install.sh`          | Homebrew packages; Kitty CLI wiring; macOS applet “Open Here in Kitty”.                           |
| `install/ubuntu-install.sh`         | apt packages; Kitty install + desktop entries; Ghostty (or Kitty fallback); fonts; picom service. |
| `install/termux-install.sh`         | pkg packages; Zsh plugins; Nerd font; Termux ergonomics.                                          |
| `install/nixos-install.sh`          | NixOS snippet; guidance.                                                                          |
| `install/refresh.sh`                | Idempotent refresh of prompt/CLIs and local overrides.                                            |
| `scripts/setup_gpg_ssh.sh`          | Wire gpg-agent→SSH; per‑OS agent conf; export SSH pub; login snippet; optional git signing.       |
| `scripts/yk-status.sh`              | Inspect sockets, keys, sshcontrol, and optional remote test.                                      |
| `scripts/yk-lock.sh`                | Clear agent caches; restart scdaemon/gpg-agent.                                                   |
| `scripts/neofetch_random.sh`        | Smart backend choice; draws random image alongside neofetch.                                      |
| `scripts/doctor.sh`                 | Health checks for PATH, nvim, prompt, git helper, tmux, SF CLI.                                   |
| `scripts/repo_to_text`              | Emit a text snapshot of repo structure/files with a globby ignore.                                |
| `scripts/sfssh`, `scripts/sftunnel` | Convenience wrappers around SF Compute CLI.                                                       |

> All scripts are linked into `~/.local/bin` (both with and without `.sh`).

---

## Picom (Linux/X11)

* Config at `picom/picom.conf` enforces app‑specific opacity (kitty/wezterm at 80%).
* `systemd --user` unit `systemd/user/picom.service` is linked and **ExecCondition**-gated to X11.

---

## Directory layout (abridged)

```
.dotfiles/
  fontconfig/30-google-sans-mono-mono.conf
  ghostty/config         kitty/kitty.conf      wezterm/wezterm.lua
  git/gitconfig          ssh/{config,sshd_config_secure}
  gnupg/*.conf           systemd/user/picom.service
  install/*.sh           scripts/*             tmux/tmux.conf
  neofetch/*.conf        oh-my-posh/config.json
  termux/*               vim/{vimrc,pyproject.toml}
  zsh/*                  .pre-commit-config.yaml
```

---

## Uninstall / rollback

This is a pure‑symlink setup:

* Remove symlinks you don’t want under `~`, or delete `~/.dotfiles` + hand‑pick from the timestamped backups.
* Remove OS flags at `${XDG_STATE_HOME:-~/.local/state}/dotfiles/` if you want a clean slate.

---

## FAQ / Notes

* **Where do machine‑local secrets go?** `zsh/90-local.zsh` (auto-created; `0600`).
* **Why Google Sans?** Optional aesthetics; Fontconfig rule ensures mono spacing for terminals.
* **Can I skip fonts?** Yes—Ubuntu task will skip Google Sans if SSH cloning fails.
* **What does `doctor.sh` warn about?** It checks presence of core tools and advises on credential helpers and Nerd Fonts.

---

## License

No license declared yet. Add one if you plan to share/reuse widely.

---

*Last updated: {{DATE}}*
