# Tensor Setup Guide

> **TODO (post-migration rewrite):** This guide documents the Ubuntu + standalone home-manager path. After the Tensor NixOS migration (Phase 6 of `claude/plans/im-about-to-begin-swift-blum.md`) and the 5090 transplant (Phase 11), this document needs a rewrite: NixOS-installer path instead of `home-manager switch`, RTX 5090 instead of 3080 in the verification block. Leaving as-is for historical reference until the migration lands.

Step-by-step instructions for applying the Nix home-manager configuration
to **Tensor** (secondary ML server, Ubuntu, RTX 3080, 32GB RAM, IP 192.168.68.11).

## What This Does

Tensor runs **standalone home-manager on Ubuntu** (not NixOS). This means:

- **Nix manages:** Your user environment -- zsh shell, git config, GPG/SSH setup,
  neovim, tmux, terminal emulators, CLI tools (fzf, bat, eza, ripgrep, etc.),
  developer tools (uv, rustup, nodejs, just), fonts, and Claude Code settings.
- **Ubuntu continues to manage:** The kernel, NVIDIA driver, CUDA toolkit, sshd,
  networking, system services, apt packages.

After this setup, your shell environment on Tensor will be identical to Manifold
(minus the desktop/Niri components which are only on the NixOS workstation).
Changes to the dotfiles repo automatically propagate to both machines by running
`home-manager switch` on each.

## What Will Change on Tensor

The following files/directories will be **created or replaced** by home-manager:

| File | What it becomes | What it replaces |
|------|----------------|-----------------|
| `~/.zshrc` | Nix-managed (symlink to Nix store) | Your current hand-written zshrc |
| `~/.zshenv` | Nix-managed | Your current zshenv |
| `~/.gitconfig` | Nix-managed (GPG signing, delta, aliases) | Your current gitconfig |
| `~/.config/nvim/init.vim` | Nix-managed (loads existing vimrc via Nix) | Your current neovim config |
| `~/.vimrc` | Nix-managed | Your current vimrc |
| `~/.tmux.conf` | Nix-managed (loads existing tmux.conf via Nix) | Your current tmux config |
| `~/.config/ghostty/config` | Nix-generated | Your current Ghostty config |
| `~/.config/kitty/kitty.conf` | Nix-generated | Your current Kitty config |
| `~/.config/wezterm/wezterm.lua` | Symlink to dotfiles repo | Your current WezTerm config |
| `~/.config/oh-my-posh/config.json` | Symlink to dotfiles repo | Your current OMP config |
| `~/.gnupg/gpg.conf` | Nix-managed (hardened settings) | Your current GPG config |
| `~/.gnupg/gpg-agent.conf` | Nix-managed (SSH support, pinentry-gnome3) | Your current agent config |
| `~/.ssh/config` | Nix-managed (Tailscale hosts, mcopp) | Your current SSH config |
| `~/.claude/` | Symlinks to dotfiles repo (settings, commands, rules) | Your current Claude config |
| `~/.local/bin/*` | Symlinks to dotfiles scripts | Your current script links |
| `~/.config/fontconfig/` | Nix-managed (Google Sans Mono spacing fix) | Your current fontconfig |

All original files are backed up in Step 4 before any changes happen.

---

## Prerequisites

Before starting, verify these are set up on Tensor. SSH in and run each check:

```bash
ssh Tensor
```

### Check 1: Ubuntu is running and accessible

```bash
lsb_release -a
# Expected output (or similar):
# Distributor ID: Ubuntu
# Description:    Ubuntu 25.10
# Release:        25.10
# Codename:       plucky
```

If you cannot SSH into Tensor, verify:
- Tailscale is running on both machines (`tailscale status`)
- sshd is listening on port 40822 (`sudo ss -tlnp | grep 40822`)
- Your SSH config on Manifold has the Tensor entry (`grep -A3 Tensor ~/.ssh/config`)

### Check 2: NVIDIA driver is installed

```bash
nvidia-smi
# Expected output:
# +-------------------------------------------+
# | NVIDIA-SMI 5xx.xx    Driver Version: 5xx.xx |
# | GPU  Name        ...  RTX 3080             |
# +-------------------------------------------+
```

If `nvidia-smi` is not found or shows an error:
```bash
sudo apt update
sudo apt install nvidia-driver-560  # or the latest version for your kernel
sudo reboot
```

### Check 3: CUDA toolkit is installed

```bash
nvcc --version
# Expected output:
# nvcc: NVIDIA (R) Cuda compiler driver
# Cuda compilation tools, release 12.x, Vxx.xx.xx

echo $CUDA_PATH
# Expected: /usr/local/cuda (or empty -- Tensor home.nix will set this)

ls /usr/local/cuda/bin/nvcc
# Should exist
```

If CUDA is not installed:
```bash
# Follow NVIDIA's official CUDA installation guide for Ubuntu
# https://developer.nvidia.com/cuda-downloads
# Choose: Linux > x86_64 > Ubuntu > your version > deb (network)
```

### Check 4: Tailscale is installed and connected

```bash
tailscale status
# Expected output: shows list of peers including Manifold, Jacobian, etc.
# Your machine should show as "Tensor" in the list

tailscale ip
# Should show a 100.x.x.x Tailscale IP
```

If Tailscale is not installed:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### Check 5: GPG and smartcard support

```bash
# Check pcscd (smartcard daemon for YubiKey)
systemctl status pcscd
# Should show: active (running)

# If not installed:
sudo apt install pcscd scdaemon gnupg
sudo systemctl enable --now pcscd
```

### Check 6: Git is installed

```bash
git --version
# Expected: git version 2.x.x
```

If any prerequisite is missing, you can run the existing dotfiles Ubuntu
installer which handles all of them:

```bash
# This installs apt packages, sets up SSH server, installs Tailscale, etc.
bash ~/.dotfiles/install/ubuntu-install.sh
```

---

## Step 1: Install Nix (multi-user mode)

Nix is a package manager that installs alongside apt without conflicting.
It stores all packages in `/nix/store` and manages user environments via
profiles at `~/.nix-profile`. The multi-user (daemon) mode is required for
reliable builds and proper garbage collection.

### 1.1: Run the installer

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

The installer will:
1. Create the `/nix` directory (requires sudo)
2. Create build users (`nixbld1` through `nixbld32`) for sandboxed builds
3. Install the Nix daemon as a systemd service (`nix-daemon.service`)
4. Add Nix to your shell profile (`/etc/profile.d/nix.sh`)

**You will be prompted to confirm several times.** Answer `y` to each prompt.

Expected output at the end:
```
 Nix is now installed!

 To use it, restart your shell or run:
   . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### 1.2: Activate Nix in the current shell

You have two options -- either source the profile or log out and back in:

```bash
# Option A: Source the profile (immediate, current session only)
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Option B: Log out and back in (permanent, affects all future sessions)
exit
ssh Tensor
```

### 1.3: Verify Nix is working

```bash
nix --version
# Expected: nix (Nix) 2.28.x (or similar)
# If you get "command not found", try Option B above (log out and back in)

# Verify the daemon is running
systemctl status nix-daemon
# Expected: active (running)

# Quick test: build something from nixpkgs
nix-shell -p hello --run hello
# Expected: "Hello, world!"
# This downloads a tiny package to verify the binary cache works
```

If `nix --version` works but `nix-shell` hangs, your network may be blocking
the binary cache. Check your firewall/proxy settings.

---

## Step 2: Enable Flakes

Flakes are Nix's reproducible project system. They're marked "experimental"
but are the standard way to manage NixOS and home-manager configurations.
Our dotfiles flake requires them.

### 2.1: Create the Nix config directory and file

```bash
mkdir -p ~/.config/nix
```

### 2.2: Add the experimental features setting

```bash
# Check if the file already exists with the setting
grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null

# If grep found nothing (exit code 1), add it:
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

If the file already exists with different experimental features, edit it:
```bash
# View current contents
cat ~/.config/nix/nix.conf

# Edit to ensure this line is present:
# experimental-features = nix-command flakes
```

### 2.3: Verify flakes work

```bash
nix flake --help
# Expected: Shows flake subcommand help text starting with:
# Usage: nix flake <command> ...
# ...

# If you get "error: experimental Nix feature 'flakes' is disabled",
# the config file wasn't picked up. Restart the daemon:
sudo systemctl restart nix-daemon
# Then try again
```

---

## Step 3: Clone the Dotfiles Repo

The dotfiles repo must be at `~/.dotfiles` because many Nix modules create
symlinks pointing to `${HOME}/.dotfiles/...` paths. If the repo is at a
different path, the symlinks will be broken.

### 3.1: If the dotfiles repo is NOT already cloned on Tensor

```bash
# Clone via SSH (uses your GPG SSH key via the agent)
git clone git@github.com:BeeGass/.dotfiles.git ~/.dotfiles

# If SSH auth fails (YubiKey not inserted, GPG agent not running), use HTTPS:
git clone https://github.com/BeeGass/.dotfiles.git ~/.dotfiles
```

### 3.2: Switch to the NixOS migration branch

```bash
cd ~/.dotfiles
git checkout feat/nixos-niri-migration
```

Expected output:
```
Branch 'feat/nixos-niri-migration' set up to track remote branch 'feat/nixos-niri-migration' from 'origin'.
Switched to a new branch 'feat/nixos-niri-migration'
```

### 3.3: If the dotfiles repo IS already cloned on Tensor

```bash
cd ~/.dotfiles
git fetch origin
git checkout feat/nixos-niri-migration

# If already on the branch, pull latest:
git pull origin feat/nixos-niri-migration
```

### 3.4: Verify the flake exists

```bash
ls -la ~/.dotfiles/flake.nix
# Should show the flake.nix file

ls ~/.dotfiles/nix/hosts/tensor/home.nix
# Should show the Tensor-specific home-manager config
```

---

## Step 4: Back Up Existing Config Files

Home-manager creates symlinks for config files it manages. If the target file
already exists as a regular file (not a symlink), home-manager will **refuse
to overwrite it** and the switch will fail. You must move the existing files
out of the way first.

### 4.1: Run the backup script

```bash
# Create a backup directory with today's date
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backing up to: $BACKUP_DIR"

# Shell configs
[ -f ~/.zshrc ] && mv ~/.zshrc "$BACKUP_DIR/" && echo "  backed up .zshrc"
[ -f ~/.zshenv ] && mv ~/.zshenv "$BACKUP_DIR/" && echo "  backed up .zshenv"
[ -f ~/.zprofile ] && mv ~/.zprofile "$BACKUP_DIR/" && echo "  backed up .zprofile"

# Git
[ -f ~/.gitconfig ] && mv ~/.gitconfig "$BACKUP_DIR/" && echo "  backed up .gitconfig"

# Vim/Neovim
[ -f ~/.vimrc ] && mv ~/.vimrc "$BACKUP_DIR/" && echo "  backed up .vimrc"
[ -f ~/.config/nvim/init.vim ] && mv ~/.config/nvim/init.vim "$BACKUP_DIR/nvim-init.vim" && echo "  backed up nvim/init.vim"

# Tmux
[ -f ~/.tmux.conf ] && mv ~/.tmux.conf "$BACKUP_DIR/" && echo "  backed up .tmux.conf"

# Terminal emulators
[ -d ~/.config/ghostty ] && mv ~/.config/ghostty "$BACKUP_DIR/ghostty" && echo "  backed up ghostty/"
[ -d ~/.config/kitty ] && mv ~/.config/kitty "$BACKUP_DIR/kitty" && echo "  backed up kitty/"
[ -d ~/.config/wezterm ] && mv ~/.config/wezterm "$BACKUP_DIR/wezterm" && echo "  backed up wezterm/"

# Oh My Posh
[ -d ~/.config/oh-my-posh ] && mv ~/.config/oh-my-posh "$BACKUP_DIR/oh-my-posh" && echo "  backed up oh-my-posh/"

# GPG (be very careful here -- don't move the actual keyring, just the config)
[ -f ~/.gnupg/gpg.conf ] && mv ~/.gnupg/gpg.conf "$BACKUP_DIR/gpg.conf" && echo "  backed up gpg.conf"
[ -f ~/.gnupg/gpg-agent.conf ] && mv ~/.gnupg/gpg-agent.conf "$BACKUP_DIR/gpg-agent.conf" && echo "  backed up gpg-agent.conf"

# SSH (back up config file only, not keys)
[ -f ~/.ssh/config ] && mv ~/.ssh/config "$BACKUP_DIR/ssh-config" && echo "  backed up ssh/config"

# Fontconfig
[ -d ~/.config/fontconfig ] && mv ~/.config/fontconfig "$BACKUP_DIR/fontconfig" && echo "  backed up fontconfig/"

# Neofetch
[ -d ~/.config/neofetch ] && mv ~/.config/neofetch "$BACKUP_DIR/neofetch" && echo "  backed up neofetch/"

# Claude Code
[ -f ~/.claude/settings.json ] && mv ~/.claude/settings.json "$BACKUP_DIR/claude-settings.json" && echo "  backed up claude/settings.json"
[ -f ~/.claude/CLAUDE.md ] && mv ~/.claude/CLAUDE.md "$BACKUP_DIR/claude-CLAUDE.md" && echo "  backed up claude/CLAUDE.md"

echo ""
echo "Backup complete. All files saved to: $BACKUP_DIR"
echo "You can restore them later with: cp -r $BACKUP_DIR/* ~/"
```

### 4.2: Verify nothing blocks the switch

```bash
# These paths should NOT exist (or be symlinks, which is fine):
for f in ~/.zshrc ~/.zshenv ~/.gitconfig ~/.vimrc ~/.tmux.conf ~/.ssh/config; do
  if [ -f "$f" ] && [ ! -L "$f" ]; then
    echo "WARNING: $f still exists as a regular file -- home-manager will fail"
  fi
done
# Expected: no output (all files were moved)
```

---

## Step 5: Apply the Home-Manager Configuration

This is the main step. Nix will download home-manager, evaluate the flake,
build all packages, and activate the new environment.

### 5.1: Run the switch command

```bash
cd ~/.dotfiles

# Use `nix run` to execute home-manager from the flake without installing it globally
nix run home-manager -- switch --flake .#beegass@tensor
```

**What this command does, in order:**

1. `nix run home-manager --` -- Downloads and runs the home-manager CLI from
   the flake's home-manager input (cached after first run)
2. `switch` -- Tells home-manager to build and activate the configuration
3. `--flake .#beegass@tensor` -- Points to the `homeConfigurations."beegass@tensor"`
   output defined in `flake.nix`, using the current directory (`.`) as the flake

### 5.2: What to expect during the first run

The first run will take **5-20 minutes** depending on your internet speed
because Nix needs to download all packages from binary caches. You'll see
output like:

```
copying path '/nix/store/abc123-zsh-5.9' from 'https://cache.nixos.org'...
copying path '/nix/store/def456-neovim-0.10.3' from 'https://cache.nixos.org'...
copying path '/nix/store/ghi789-tmux-3.5' from 'https://cache.nixos.org'...
... (many more packages)

activating homManagerConfiguration for beegass@tensor
```

At the end you should see:

```
Activating home-manager configuration for beegass
...
Creating profile generation N
```

### 5.3: If the switch fails

**"Existing file" error:**
```
Existing file '/home/beegass/.zshrc' is in the way of
'/nix/store/xxx-home-manager-files/.zshrc'
```
Fix: Back up the offending file and re-run:
```bash
mv ~/.zshrc ~/.zshrc.backup
nix run home-manager -- switch --flake .#beegass@tensor
```

**"attribute not found" error:**
```
error: flake 'path:/home/beegass/.dotfiles' does not provide attribute
'homeConfigurations.beegass@tensor'
```
Fix: Make sure you're on the right branch:
```bash
cd ~/.dotfiles
git branch --show-current
# Must be: feat/nixos-niri-migration
```

**"infinite recursion" or evaluation error:**
This means a bug in the Nix config. Note the full error message and file path,
then fix it in the dotfiles repo and re-run.

**Network timeout:**
```
error: unable to download 'https://cache.nixos.org/...'
```
Fix: Check your internet connection. If behind a proxy, configure Nix:
```bash
echo "proxy = http://your-proxy:port" >> ~/.config/nix/nix.conf
sudo systemctl restart nix-daemon
```

---

## Step 6: Restart Your Shell

Home-manager has now activated, but your current shell session still uses
the old environment. You need to reload it.

### 6.1: Reload the shell

```bash
# Replace the current shell process with the new zsh
exec zsh
```

### 6.2: What you should see

After `exec zsh`, you should see:

1. A **system info banner** from pfetch or fastfetch (shows hostname, OS, kernel,
   uptime, packages, shell, terminal, CPU, memory)

2. The **Oh My Posh prompt** with:
   - Left side: OS icon, current directory, git branch/status (if in a repo)
   - Right side: language context (Python version, Node version, Rust version
     if relevant files are detected)
   - Second line: `>` character (green on success, red on last command failure)

If you see a plain `$` prompt instead of Oh My Posh, check:
```bash
which oh-my-posh
# Should show a Nix store path like /nix/store/xxx-oh-my-posh-xxx/bin/oh-my-posh

echo $OH_MY_POSH_CONFIG
# Should show: /home/beegass/.config/oh-my-posh/config.json

ls -la ~/.config/oh-my-posh/config.json
# Should show a symlink to ~/.dotfiles/oh-my-posh/config.json
```

---

## Step 7: Verify Everything Works

Go through each section systematically. If any check fails, see the
troubleshooting section at the bottom.

### 7.1: Shell environment

```bash
echo $SHELL
# Expected: a zsh path (may be /usr/bin/zsh or a Nix store path)

echo $EDITOR
# Expected: nvim

echo $CUDA_PATH
# Expected: /usr/local/cuda (set by Tensor's home.nix)

# Test vi-mode: press Escape, then press 'k' to go up in history
# Press 'i' to go back to insert mode
```

### 7.2: Zsh aliases

```bash
# These should all work (defined in shell.nix shellAliases):
ls      # runs eza with --classify --group-directories-first
ll      # runs eza -lgh --icons --group-directories-first
la      # runs eza -lgha --icons --group-directories-first
cat     # runs bat --paging=never --style=plain
grep    # runs rg -n --color=auto
```

### 7.3: Git configuration

```bash
git config user.name
# Expected: Bryan Gass

git config user.email
# Expected: bryank123@live.com

git config user.signingkey
# Expected: 0xACC3640C138D96A2

git config core.pager
# Expected: delta
```

### 7.4: GPG and YubiKey

Insert your YubiKey into Tensor (or plug it into a USB hub if remote):

```bash
gpg --card-status
# Expected: Shows card info with your key IDs:
#   Signature key ....: <your signing key>
#   Encryption key....: <your encryption key>
#   Authentication key: <your auth key>

# Verify GPG agent is serving SSH keys:
ssh-add -l
# Expected: Shows one or more GPG-backed SSH keys
# e.g., 4096 SHA256:xxxx cardno:xxxx (RSA)

# Test GPG signing:
echo "test" | gpg --clearsign
# Should prompt for YubiKey PIN, then output a signed message
```

### 7.5: SSH connectivity

```bash
# Test SSH to GitHub (uses GPG auth key via gpg-agent)
ssh -T git@github.com
# Expected: Hi BeeGass! You've been authenticated...

# Test SSH to other homelab hosts (requires Tailscale)
ssh Manifold echo "connected"
# Expected: connected

ssh Jacobian echo "connected"
# Expected: connected
```

### 7.6: NVIDIA and CUDA (system-level, not Nix-managed)

```bash
nvidia-smi
# Expected: Shows RTX 3080, driver version, CUDA version

nvcc --version
# Expected: CUDA compilation tools version

echo $CUDA_PATH
# Expected: /usr/local/cuda

# Test GPU monitoring tool (installed by Nix via Tensor home.nix):
nvtop
# Expected: Live GPU utilization display (press q to exit)
```

### 7.7: CLI tools

```bash
# Each of these should resolve to a /nix/store/... path:
which fzf && fzf --version
which bat && bat --version
which eza && eza --version
which rg && rg --version
which fd && fd --version
which delta && delta --version
which jq && jq --version
which gh && gh --version
which just && just --version
which uv && uv --version
which rustup && rustup --version

# Test fzf integration (Ctrl+R should open fuzzy history search):
# Press Ctrl+R, type a partial command, select with arrow keys, press Enter
```

### 7.8: Neovim

```bash
nvim --version
# Expected: NVIM v0.10.x (or similar)

# Open neovim and check plugins load:
nvim
# Expected: vim-plug should auto-install missing plugins on first launch
# You'll see ":PlugInstall" running automatically
# Wait for it to finish, then :q to exit

# Verify Colemak-DH navigation works:
# In normal mode: r=left, s=down, f=up, t=right
```

### 7.9: Tmux

```bash
# Start or attach to a tmux session:
tmux new-session -A -s main

# Expected:
# - Status bar at bottom with transparent background
# - Amber (#f7ca88) active window tab
# - Session name, time, hostname on the right side

# Test keybindings:
# Alt+c        = new window
# Alt+1-9      = switch to window N
# Alt+\        = vertical split
# Alt+-        = horizontal split
# Alt+Arrow    = navigate panes
# Ctrl+Space   = prefix (fallback)
# Ctrl+Space r = reload config

# Exit: type `exit` or press Ctrl+d
```

### 7.10: Direnv and Nix dev shells

```bash
# Test that direnv auto-activates on cd:
mkdir -p /tmp/test-direnv && cd /tmp/test-direnv
echo "use flake github:NixOS/nixpkgs#hello" > .envrc
direnv allow
# Expected: direnv loads the flake, `hello` becomes available
hello
# Expected: "Hello, world!"
cd ~ && rm -rf /tmp/test-direnv
```

### 7.11: Claude Code (optional)

If Claude Code is installed:

```bash
claude --version
# Expected: Claude Code version string

# Check systemd services (these run Remote Control servers):
systemctl --user list-units 'claude-rc-*'
# Expected: Shows 4 services (may be inactive on Tensor if not needed)
```

---

## Step 8: Install Fonts

Home-manager installs **JetBrains Mono Nerd Font** and **Nerd Font Symbols**
automatically. These provide icons in the terminal and prompt.

**Google Sans Mono** (the primary font in Ghostty/Kitty/WezTerm configs) is
NOT in nixpkgs and must be installed manually. Without it, terminals fall
back to JetBrains Mono (which works fine but looks slightly different).

### 8.1: Check if Google Sans Mono is already installed

```bash
fc-list | grep -i "google sans mono"
# If you see output, it's already installed -- skip to Step 9
```

### 8.2: Install Google Sans Mono

```bash
mkdir -p ~/.local/share/fonts

# Clone the font repo (requires SSH access to GitHub):
git clone git@github.com:mehant-kr/Google-Sans-Mono.git /tmp/google-sans-mono

# Copy the font files:
find /tmp/google-sans-mono -name '*.ttf' -exec cp {} ~/.local/share/fonts/ \;

# Rebuild the font cache:
fc-cache -fv

# Verify it's detected:
fc-list | grep -i "google sans mono"
# Expected: One or more lines showing Google Sans Mono font files

# Clean up:
rm -rf /tmp/google-sans-mono
```

### 8.3: Also install Google Sans (regular, for GTK apps)

```bash
git clone git@github.com:nicholasgasior/gfonts.git /tmp/gfonts
find /tmp/gfonts -path "*/Google_Sans/*" -name '*.ttf' -exec cp {} ~/.local/share/fonts/ \;
fc-cache -fv
rm -rf /tmp/gfonts
```

---

## Step 9: Set Zsh as Default Shell

Home-manager installs zsh via Nix, but doesn't change your login shell.
You need to set it manually.

### 9.1: Find the Nix-managed zsh path

```bash
which zsh
# Expected: /home/beegass/.nix-profile/bin/zsh
# or: /nix/store/xxx-zsh-5.9/bin/zsh
```

### 9.2: Add it to the system's allowed shells

```bash
# Check if it's already in /etc/shells
grep "$(which zsh)" /etc/shells
# If no output, add it:
echo "$(which zsh)" | sudo tee -a /etc/shells
```

### 9.3: Change your default shell

```bash
chsh -s "$(which zsh)"
# Enter your password when prompted
```

### 9.4: Verify the change

```bash
# Log out and back in:
exit
ssh Tensor

# Check the shell:
echo $SHELL
# Expected: /home/beegass/.nix-profile/bin/zsh (or similar Nix path)
```

**Important note:** If you later remove Nix, your login shell will point to
a path that no longer exists and you won't be able to log in normally. To fix
that, you'd need to use `sudo chsh -s /bin/bash beegass` from a root shell
or recovery console.

---

## Day-to-Day Usage

### Updating after dotfiles changes

When changes are pushed to the dotfiles repo:

```bash
cd ~/.dotfiles
git pull

# Re-apply the configuration
home-manager switch --flake .#beegass@tensor
```

If the switch succeeds, you're done. If it fails, check the error message --
most likely a Nix syntax error in a changed file.

### Updating Nix packages

To get newer versions of all packages (nixpkgs, home-manager, etc.):

```bash
cd ~/.dotfiles
nix flake update          # Updates flake.lock with latest versions
home-manager switch --flake .#beegass@tensor  # Applies updated packages
```

**Note:** This may change package versions (e.g., neovim 0.10.2 -> 0.10.3).
If something breaks, roll back (see below).

### Rolling back

Home-manager keeps a history of every activation. To roll back:

```bash
# List all generations with timestamps:
home-manager generations
# Output:
# 2026-03-29 14:32 : id 3 -> /nix/store/xxx-home-manager-generation
# 2026-03-29 10:15 : id 2 -> /nix/store/yyy-home-manager-generation
# 2026-03-28 16:00 : id 1 -> /nix/store/zzz-home-manager-generation

# Activate a previous generation (replace N with the generation number):
/nix/var/nix/profiles/per-user/beegass/home-manager-N-link/activate

# Restart your shell to pick up the rolled-back config:
exec zsh
```

### Garbage collecting old packages

Nix keeps all downloaded packages in `/nix/store` forever. To reclaim disk space:

```bash
# Remove old home-manager generations (keeps the current one):
home-manager expire-generations "-7 days"

# Remove unreferenced packages from the Nix store:
nix-collect-garbage -d

# Check how much space /nix uses:
du -sh /nix/store
```

---

## Troubleshooting

### "experimental-features" error

```
error: experimental Nix feature 'flakes' is disabled
```

**Fix:** Ensure `~/.config/nix/nix.conf` contains:
```
experimental-features = nix-command flakes
```
Then restart the daemon:
```bash
sudo systemctl restart nix-daemon
```

### "Existing file is in the way"

```
Existing file '/home/beegass/.zshrc' is in the way
```

**Fix:** Move the conflicting file:
```bash
mv ~/.zshrc ~/.zshrc.backup
# Then re-run the switch command
```

### "command not found" after switch

Your current shell doesn't know about the new Nix-managed binaries yet.

**Fix:**
```bash
exec zsh  # Replace the shell process with the new one
```

If that doesn't work, check your PATH:
```bash
echo $PATH | tr ':' '\n' | head -10
# Should include:
# /home/beegass/.nix-profile/bin
# /nix/var/nix/profiles/default/bin
```

### GPG agent not starting or SSH key not found

```bash
# Kill and restart the agent
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

# Re-export the socket
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"

# Verify
gpg --card-status   # Should show YubiKey info
ssh-add -l          # Should show the GPG auth key
```

### Oh My Posh prompt not showing

```bash
# Check if oh-my-posh is installed
which oh-my-posh
# If "not found": the switch didn't complete properly, re-run it

# Check if the config exists
ls -la ~/.config/oh-my-posh/config.json
# Should be a symlink to ~/.dotfiles/oh-my-posh/config.json

# Test OMP directly
oh-my-posh init zsh --config ~/.config/oh-my-posh/config.json
# If this errors, the config.json may be missing or corrupt
```

### Fonts look wrong (no icons, missing symbols)

```bash
# Check if Nerd Fonts are installed
fc-list | grep -i "JetBrains Mono Nerd"
# Should show JetBrainsMono Nerd Font entries

# If missing, the home-manager font installation may have failed.
# Check the switch output for font-related errors and re-run.

# Your terminal emulator must also be configured to use a Nerd Font.
# The Ghostty/Kitty configs already do this, but if using a different
# terminal, set the font to "JetBrainsMono Nerd Font" or "Google Sans Mono"
```

### Slow first build (15+ minutes)

This is normal. Nix downloads all packages from `cache.nixos.org` on the first run.
Subsequent runs use the local `/nix/store` cache and take only seconds.

If it's very slow (>30 minutes), check if you have the binary caches configured:
```bash
cat ~/.config/nix/nix.conf
# Should contain: experimental-features = nix-command flakes
# The flake itself configures the CUDA and niri caches for NixOS hosts,
# but for standalone home-manager, only cache.nixos.org is used
```

### Nix store running out of disk space

```bash
# Check disk usage
du -sh /nix/store
df -h /nix

# Aggressive cleanup
nix-collect-garbage -d
nix-store --gc
nix-store --optimise  # Hard-link duplicate files (slow but saves space)
```
