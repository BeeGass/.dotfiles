# BeeGass Dotfiles

Declarative, idempotent dotfiles managed by [chezmoi](https://www.chezmoi.io/) across macOS, Ubuntu/Linux, Raspberry Pi, HPC clusters, and Termux. OS-aware templates handle per-platform differences (credential helpers, pinentry programs, PATH seeds) so one source tree works everywhere.

---

## TL;DR (Quickstart)

**Bootstrap (recommended for bare machines)**

```bash
# Installs git + chezmoi, clones repo, applies dotfiles
curl -fsSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/bootstrap.sh | bash
```

**Using `just` (if repo is already cloned)**

```bash
git clone https://github.com/BeeGass/.dotfiles ~/.dotfiles
cd ~/.dotfiles
just apply
```

**Manual (no `just` required)**

```bash
git clone https://github.com/BeeGass/.dotfiles ~/.dotfiles
chezmoi init --apply --source ~/.dotfiles
```

> Re-run `just apply` or `chezmoi apply` any time -- it's idempotent. Files marked `create_` are never overwritten once written.

---

## Supported platforms

* **macOS** (Homebrew-based)
* **Ubuntu/Linux** (apt; Kitty + Ghostty)
* **Raspberry Pi** (apt; headless-friendly)
* **HPC clusters** (no sudo; user-space tools only)
* **Termux (Android)** (pkg; ergonomic mobile defaults)

---

## How chezmoi works here

chezmoi manages dotfiles declaratively: source files under `home/` are deployed to `~` using naming conventions that control behavior:

| Prefix/Suffix | Effect |
|---------------|--------|
| `dot_` | Becomes a `.` in the target name |
| `private_` | File deployed with mode `0600` |
| `create_` | Written once; never overwritten by subsequent applies |
| `exact_` | Directory is mirrored exactly (extra files removed) |
| `symlink_` | Creates a symbolic link instead of a copy |
| `.tmpl` | Processed as a Go template with machine-specific data |

During `chezmoi init`, the machine is classified interactively:

```yaml
# ~/.config/chezmoi/chezmoi.yaml (auto-generated)
data:
  machineType: "desktop"    # desktop | server | hpc
  machineName: "Matrix"     # Manifold | Tensor | Matrix | Hessian | Jacobian | Vector
  isTermux: false
  isRpi: false
  isHpc: false
```

Templates use these values for OS and machine-specific branching (credential helpers, pinentry programs, PATH seeds, package lists, etc.).

---

## Task runner (`just`)

[`just`](https://github.com/casey/just) is the primary interface. All recipes are listed with `just --list`.

### Chezmoi recipes

| Recipe | Description |
|--------|-------------|
| `just apply` | Apply dotfiles to this machine |
| `just update` | Pull latest changes from git and apply |
| `just diff` | Show what would change |
| `just status` | Show managed file status |
| `just edit <file>` | Edit a chezmoi-managed file (opens source + target) |
| `just sync` | Re-add modified target files back to chezmoi source |
| `just bootstrap` | Bootstrap on a fresh machine (`chezmoi init --apply`) |
| `just dry-run` | Dry-run apply (preview changes without modifying) |
| `just rerun-scripts` | Force re-run all one-time setup scripts |
| `just chezmoi-doctor` | Run chezmoi diagnostics |

### Secrets recipes

| Recipe | Description |
|--------|-------------|
| `just secrets-check` | Verify connectivity to pass store and secrets server |
| `just secrets-load` | Load secrets into current session |
| `just secrets-init` | Initialize pass store with GPG key |
| `just secrets-push` | Push pass store to git remote |
| `just secrets-pull` | Pull pass store from git remote |

### Utility recipes

| Recipe | Description |
|--------|-------------|
| `just doctor` | Run system health checks |
| `just yk-status` | Show YubiKey status |
| `just yk-refresh` | Refresh YubiKey GPG configuration |
| `just yk-lock` | Lock YubiKey (clear PIN caches) |

---

## What chezmoi deploys

### 1. Config files (via templates and copies)

* `~/.zshrc`, `~/.zshenv` (OS-aware PATH template), `~/.gitconfig` (OS-aware credential helper)
* `~/.vimrc`, `~/.tmux.conf`, `~/.ssh/config`, `~/.gnupg/*`
* `~/.config/{kitty,wezterm,ghostty,oh-my-posh,neofetch,nvim,picom,systemd}`
* `~/.claude/` (settings, hooks, docs, templates, commands)
* `~/.termux/` (Termux only)
* `~/.config/nvim/init.vim` symlinked to `~/.vimrc`

### 2. Machine-local overrides (create-once)

* `~/.dotfiles/zsh/90-local.zsh` -- GPG/SSH agent wiring, environment variables, PATH additions. Written once with `0600` permissions; never overwritten.
* `~/.config/kitty/local.conf` -- tmux autostart, Linux-specific X11/Nerd Font config. Written once; edit freely.

### 3. Platform packages (via chezmoi scripts)

* **macOS**: Homebrew taps, brews, and casks (defined in `.chezmoidata.yaml`)
* **Ubuntu/Linux**: apt packages (defined in `.chezmoidata.yaml`)
* **HPC**: user-space only (uv, cargo tools, fzf, oh-my-posh)
* **Termux**: pkg packages, Zsh plugins, Nerd font

### 4. Developer tooling (via chezmoi scripts)

* **oh-my-posh** prompt + theme at `~/.config/oh-my-posh/config.json`
* **uv** (Python launcher/PM); installs CPython 3.11-3.14; tools: `ruff`, `mypy`, `pytest`, `pre-commit`, `python-lsp-server`
* **Node** via `nvm` (latest LTS), plus `@google/gemini-cli`, `typescript`, `typescript-language-server`
* **tmux** plugin manager (TPM) auto-installed

### 5. System setup (via chezmoi scripts, run once)

* SSH server hardening (`99-yubikey-only.conf` deployed to `/etc/ssh/sshd_config.d/`)
* fail2ban configuration
* Kitty desktop integration (Linux)
* Ghostty installation
* Picom compositor service (Linux/X11)
* Font installation (JetBrains Mono Nerd Font, Google Sans)
* Flatpak apps, Snap packages (Linux)
* Utility scripts linked to `~/.local/bin/`

---

## Safety and design choices

* **Idempotent**: `chezmoi apply` is safe to re-run. Create-once files (`create_` prefix) are never overwritten.
* **No secrets in repo**: machine-local, private overrides live in `zsh/90-local.zsh` (auto-created, `0600`).
* **Credential helpers**: macOS: `osxkeychain`; Linux: `store`. Configured via template.
* **GPG agent config**: consolidated from 4 per-OS files into a single template selecting the correct pinentry program.
* **Termux ergonomics**: ESC/back mapping, extra keys, Nerd font, Zsh plugins.
* **Runtime-adaptive configs**: tmux, ssh, wezterm, kitty, and zsh plugin files handle OS differences at runtime (no templates needed).
* **Package lists**: centralized in `home/.chezmoidata.yaml`, used by `run_onchange_` scripts that re-run when the data file changes.

---

## First install

Use the **bootstrap one-liner**, `just apply`, or `chezmoi init --apply`. Chezmoi will:

* Prompt for machine type (desktop/server/hpc) and machine name
* Deploy all config files from `home/` to `~`
* Run platform-specific package installation scripts
* Set up developer tools (uv, node, prompt)
* Configure GPG/SSH agent
* Create machine-local override files (once)

Open a new shell or `source ~/.zshrc`.

## Update an existing machine

```bash
just update           # git pull + chezmoi apply
just apply            # apply without pulling
just dry-run          # preview what would change
```

## Health check

```bash
just doctor           # or: ~/.dotfiles/scripts/doctor.sh
just chezmoi-doctor   # chezmoi-specific diagnostics
```

## Force re-run setup scripts

If you modify a `run_once_*` chezmoi script and need it to run again:

```bash
just rerun-scripts    # clears script state, then applies
```

---

## HPC cluster setup

For shared clusters without sudo access, select `hpc` as the machine type during `chezmoi init`:

```bash
chezmoi init --apply BeeGass/.dotfiles
# Select: Machine type → hpc
```

This installs everything to `~/.local/bin` and `~/.cargo/bin`:

* Detects zsh via environment modules (`module load zsh`)
* Falls back to `.bash_profile` exec stub if `chsh` is denied
* Installs uv + Python, oh-my-posh, Rust toolchain, cargo tools (bat, fd, rg, delta, eza), fzf
* Creates an HPC-specific `90-local.zsh` with Slurm aliases and module stubs
* Skips GUI applications (kitty, wezterm, ghostty, claude) via `.chezmoiignore`

---

## Secrets management

API keys and tokens are managed via a hybrid approach: **`pass`** (GPG-encrypted password store) on machines with a YubiKey, with **SSH fallback** to a dedicated secrets server for environments without one (e.g. HPC clusters).

### Architecture

* **Secrets server** (Jacobian, RPi 5) stores plaintext keys at `~/.secrets/env`, accessible only via SSH with YubiKey auth
* **Home machines** (manifold, tensor, macOS) use `pass` with GPG encryption; keys are decrypted on demand when the YubiKey is present
* **HPC clusters** fetch secrets over SSH from the secrets server; nothing is stored on disk

### Daily usage

```bash
# Load all API keys into current shell
load-secrets

# Check what sources are available
load-secrets --check

# Manage the pass store
load-secrets --init       # first-time setup (requires YubiKey)
load-secrets --push       # sync to git remote
load-secrets --pull       # pull from git remote

# Add a new key
pass insert api/OPENAI_API_KEY
pass insert api/ANTHROPIC_API_KEY
pass insert api/HF_TOKEN
```

The `load-secrets` function (defined in `zsh/50-functions.zsh`) tries `pass` first, then falls back to SSH. On HPC, it goes straight to SSH.

### Setup

* **Secrets server setup**: see [`docs/secrets-server-setup.md`](docs/secrets-server-setup.md)
* **Client setup**: `pass` is installed automatically by the chezmoi package scripts (macOS Homebrew, Ubuntu apt). Run `just secrets-init` to initialize the store.
* **HPC**: no setup needed beyond SSH access to the secrets server

---

## GPG + SSH quickstart

```bash
# Regenerate imports and exports; wire gpg-agent -> SSH; optional: set Git signing
~/.dotfiles/scripts/setup_gpg_ssh.sh --regen --git

# Verify sockets, keys, and card
just yk-status

# Force a lock (clear caches)
just yk-lock
```

**Notes**

* Per-OS agent config is generated by chezmoi from `home/private_dot_gnupg/private_gpg-agent.conf.tmpl`.
* Shell snippet in `zsh/90-local.zsh` ensures `GPG_TTY` + SSH agent wiring on login.
* SSH config includes `Include ~/.ssh/config.d/*.conf` and ships a `10-gpg-agent.conf` drop-in.

---

## Fonts and Fontconfig

* **JetBrains Mono Nerd**: installed per-platform for glyphs used by the prompt.
* **Google Sans / Google Sans Mono**: optional, **installed via SSH cloning** on Ubuntu:
  * `git@github.com:mehant-kr/Google-Sans-Mono.git`
  * `git@github.com:hprobotic/Google-Sans-Font.git`
  * If you don't have GitHub SSH access on that machine, the step is skipped.
* `fontconfig/30-google-sans-mono-mono.conf` sets `spacing=100` to force mono metrics for Google Sans Mono.

---

## Terminals

### Kitty (Linux/macOS)

* 80% opacity; right-click paste; tmux autostart (via `local.conf`).
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

Plugins via TPM are declared at the bottom of `tmux.conf`; first-run will auto-install TPM.

---

## Scripts

| Script | What it does |
| --- | --- |
| `scripts/setup_gpg_ssh.sh` | Wire gpg-agent -> SSH; per-OS agent conf; export SSH pub; login snippet; optional git signing |
| `scripts/yk-status.sh` | Inspect sockets, keys, sshcontrol, and optional remote test |
| `scripts/yk-lock.sh` | Clear agent caches; restart scdaemon/gpg-agent |
| `scripts/yk-gpg-refresh.sh` | Refresh YubiKey GPG configuration |
| `scripts/neofetch_random.sh` | Smart backend choice; draws random image alongside neofetch |
| `scripts/load-secrets.sh` | Hybrid secrets loader: pass (GPG) with SSH fallback to secrets server |
| `scripts/doctor.sh` | Health checks for PATH, nvim, prompt, git helper, tmux, SF CLI |
| `scripts/repo_to_text` | Emit a text snapshot of repo structure/files with a globby ignore |
| `scripts/sfssh`, `scripts/sftunnel` | Convenience wrappers around SF Compute CLI |
| `scripts/lib-common.sh` | Shared logging library (section, step, ok, warn, err) used by chezmoi scripts |

> All scripts are linked into `~/.local/bin` (both with and without `.sh`) by the `run_once_after_setup-scripts.sh` chezmoi script.

---

## Picom (Linux/X11)

* Config at `picom/picom.conf` enforces app-specific opacity (kitty/wezterm at 80%).
* `systemd --user` unit `systemd/user/picom.service` is deployed and **ExecCondition**-gated to X11.

---

## Directory layout

```
.dotfiles/
  .chezmoiroot                        # Points chezmoi source to home/
  bootstrap.sh                        # Curl-able bootstrap: installs git + chezmoi
  justfile                            # Task runner entry point
  home/                               # chezmoi source directory
    .chezmoi.yaml.tmpl                # Machine config template (type, name, OS flags)
    .chezmoidata.yaml                 # Package lists (Homebrew, apt)
    .chezmoiignore                    # OS-conditional ignores
    .chezmoiscripts/                  # chezmoi run scripts
      run_onchange_before_*           # Package installers (re-run when data changes)
      run_once_before_*               # System setup (SSH server, fail2ban)
      run_once_after_*                # Dev tools, fonts, apps, scripts
    .chezmoitemplates/                # Shared template fragments
      neofetch-desktop                # Desktop neofetch config
      neofetch-termux                 # Termux neofetch config
    dot_zshrc                         # -> ~/.zshrc
    dot_zshenv.tmpl                   # -> ~/.zshenv (OS-aware PATH)
    dot_gitconfig.tmpl                # -> ~/.gitconfig (OS-aware credential helper)
    dot_vimrc                         # -> ~/.vimrc
    dot_tmux.conf                     # -> ~/.tmux.conf
    private_dot_ssh/                  # -> ~/.ssh/ (mode 0600)
    private_dot_gnupg/                # -> ~/.gnupg/ (mode 0600, templated gpg-agent)
    dot_config/                       # -> ~/.config/
      kitty/ ghostty/ wezterm/        # Terminal configs
      oh-my-posh/ neofetch/ nvim/     # Tool configs
      picom/ systemd/user/            # Linux-only (ignored on macOS via .chezmoiignore)
    dot_claude/                       # -> ~/.claude/
    dot_termux/                       # -> ~/.termux/ (Termux only)
    dot_dotfiles/zsh/                 # -> ~/.dotfiles/zsh/
      create_private_90-local.zsh.tmpl  # Machine-local overrides (write once)
  zsh/                                # Shell config sourced at runtime from ~/.dotfiles/zsh/
    00-init.zsh ... 80-tools.zsh      # Numbered files sourced in order by ~/.zshrc
  scripts/                            # Utility scripts -> ~/.local/bin/
  fontconfig/ fail2ban/ ssh/          # Configs deployed by chezmoi scripts to system paths
  neofetch/ picom/ systemd/           # Source files for chezmoi templates and scripts
  docs/                               # Documentation
```

---

## FAQ / Notes

* **Where do machine-local secrets go?** `zsh/90-local.zsh` (auto-created by chezmoi; `0600`).
* **Why Google Sans?** Optional aesthetics; Fontconfig rule ensures mono spacing for terminals.
* **Can I skip fonts?** Yes -- the font script will skip Google Sans if SSH cloning fails.
* **What does `doctor.sh` warn about?** It checks presence of core tools and advises on credential helpers and Nerd Fonts.
* **Do I need `just` installed?** No -- `chezmoi apply` works directly. `just` is a convenience wrapper.
* **How do I add a new config file?** Place it under `home/` with the appropriate chezmoi naming, then `just apply`.
* **How do I force a setup script to re-run?** `just rerun-scripts` clears chezmoi script state and re-applies.
* **What if I edit a deployed file directly?** Use `just sync` (`chezmoi re-add`) to pull changes back into the source.

---

## License

No license declared yet. Add one if you plan to share/reuse widely.
