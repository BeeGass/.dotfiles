# Dotfiles Task Runner
# ====================
# Main entry point for dotfiles management.
# Run `just --list` to see all available recipes grouped by category.
# Run `just <recipe>` to execute a specific task.

set shell := ["bash", "-euo", "pipefail", "-c"]

export DOTFILES_DIR := env_var_or_default("DOTFILES_DIR", home_directory() + "/.dotfiles")
export NO_SUDO := env_var_or_default("NO_SUDO", "0")
export DRYRUN := env_var_or_default("DRYRUN", "0")
export VERBOSE := env_var_or_default("VERBOSE", "1")
export FAST := env_var_or_default("FAST", "0")

# List all available recipes
default:
    @just --list --unsorted

# ------------------------------------------------------------------------------
# Install
# ------------------------------------------------------------------------------

# Run the main install script
[group('install')]
install *FLAGS:
    @bash "{{DOTFILES_DIR}}/install/install.sh" {{FLAGS}}

# Run Ubuntu-specific installation
[group('install')]
[linux]
install-ubuntu *FLAGS:
    @bash "{{DOTFILES_DIR}}/install/ubuntu-install.sh" {{FLAGS}}

# Run macOS-specific installation
[group('install')]
[macos]
install-macos:
    @bash "{{DOTFILES_DIR}}/install/macos-install.sh"

# Run Raspberry Pi installation
[group('install')]
[linux]
install-rpi:
    @bash "{{DOTFILES_DIR}}/install/rpi-install.sh"

# Run headless HPC cluster installation (no sudo, user-space only)
[group('install')]
[linux]
install-hpc:
    @bash "{{DOTFILES_DIR}}/install/hpc-install.sh"

# ------------------------------------------------------------------------------
# Refresh
# ------------------------------------------------------------------------------

# Refresh dotfiles configuration
[group('refresh')]
refresh *FLAGS:
    @bash "{{DOTFILES_DIR}}/install/refresh.sh" {{FLAGS}}

# Refresh with --fast flag (skip slow operations)
[group('refresh')]
refresh-fast:
    @just refresh --fast

# Refresh with --dry-run flag (preview changes)
[group('refresh')]
refresh-dry:
    @just refresh --dry-run

# ------------------------------------------------------------------------------
# Sections
# ------------------------------------------------------------------------------

# Refresh PATH configuration
[group('sections')]
refresh-path:
    @bash "{{DOTFILES_DIR}}/install/sections/path.sh"

# Refresh local configuration
[group('sections')]
refresh-local:
    @bash "{{DOTFILES_DIR}}/install/sections/local.sh"

# Refresh directory structure
[group('sections')]
refresh-directories:
    @bash "{{DOTFILES_DIR}}/install/sections/directories.sh"

# Refresh cleanup tasks
[group('sections')]
refresh-cleanup:
    @bash "{{DOTFILES_DIR}}/install/sections/cleanup.sh"

# Refresh backup configuration
[group('sections')]
refresh-backups:
    @bash "{{DOTFILES_DIR}}/install/sections/backups.sh"

# Refresh Oh My Posh configuration
[group('sections')]
refresh-omp:
    @bash "{{DOTFILES_DIR}}/install/sections/omp.sh"

# Refresh Zsh configuration
[group('sections')]
refresh-zsh:
    @bash "{{DOTFILES_DIR}}/install/sections/zsh.sh"

# Refresh Python environment
[group('sections')]
refresh-python:
    @bash "{{DOTFILES_DIR}}/install/sections/python.sh"

# Refresh Node.js environment
[group('sections')]
refresh-node:
    @bash "{{DOTFILES_DIR}}/install/sections/node.sh"

# Refresh tmux configuration
[group('sections')]
refresh-tmux:
    @bash "{{DOTFILES_DIR}}/install/sections/tmux.sh"

# Refresh SSH configuration
[group('sections')]
refresh-ssh:
    @bash "{{DOTFILES_DIR}}/install/sections/ssh.sh"

# Refresh Snap packages
[group('sections')]
refresh-snap:
    @bash "{{DOTFILES_DIR}}/install/sections/snap.sh"

# Refresh Claude configuration
[group('sections')]
refresh-claude:
    @bash "{{DOTFILES_DIR}}/install/sections/claude.sh"

# Refresh Codex CLI configuration
[group('sections')]
refresh-codex:
    @bash "{{DOTFILES_DIR}}/install/sections/codex.sh"

# Refresh Gemini configuration
[group('sections')]
refresh-gemini:
    @bash "{{DOTFILES_DIR}}/install/sections/gemini.sh"

# Refresh OpenCode configuration
[group('sections')]
refresh-opencode:
    @bash "{{DOTFILES_DIR}}/install/sections/opencode.sh"

# Refresh Flatpak packages
[group('sections')]
refresh-flatpak:
    @bash "{{DOTFILES_DIR}}/install/sections/flatpak.sh"

# Refresh Tailscale configuration
[group('sections')]
refresh-tailscale:
    @bash "{{DOTFILES_DIR}}/install/sections/tailscale.sh"

# Refresh Starship/SF configuration
[group('sections')]
refresh-sf:
    @bash "{{DOTFILES_DIR}}/install/sections/sf.sh"

# Refresh Git configuration
[group('sections')]
refresh-git:
    @bash "{{DOTFILES_DIR}}/install/sections/git.sh"

# Refresh font installation
[group('sections')]
refresh-fonts:
    @bash "{{DOTFILES_DIR}}/install/sections/fonts.sh"

# Refresh secrets management (pass store, SSH connectivity)
[group('sections')]
refresh-secrets:
    @bash "{{DOTFILES_DIR}}/install/sections/secrets.sh"

# ------------------------------------------------------------------------------
# Doctor
# ------------------------------------------------------------------------------

# Run system health checks
[group('doctor')]
doctor:
    @bash "{{DOTFILES_DIR}}/scripts/doctor.sh"

# ------------------------------------------------------------------------------
# YubiKey
# ------------------------------------------------------------------------------

# Show YubiKey status
[group('yubikey')]
yk-status:
    @bash "{{DOTFILES_DIR}}/scripts/yk-status.sh"

# Refresh YubiKey GPG configuration
[group('yubikey')]
yk-refresh:
    @bash "{{DOTFILES_DIR}}/scripts/yk-gpg-refresh.sh"

# Lock YubiKey
[group('yubikey')]
yk-lock:
    @bash "{{DOTFILES_DIR}}/scripts/yk-lock.sh"

# ------------------------------------------------------------------------------
# Utils
# ------------------------------------------------------------------------------

# Clean old backup files
[group('utils')]
clean-backups:
    @just refresh --only backups --clean-backups

# Update Oh My Posh
[group('utils')]
update-omp:
    @just refresh --only omp

# Update Python environment
[group('utils')]
update-python:
    @just refresh --only python

# Update Node.js environment
[group('utils')]
update-node:
    @just refresh --only node

# Update tmux plugins
[group('utils')]
update-tmux:
    @just refresh --only tmux

# Check secrets connectivity (pass store + SSH fallback)
[group('secrets')]
secrets-check:
    @bash "{{DOTFILES_DIR}}/scripts/load-secrets.sh" --check

# Initialize pass store for secrets management
[group('secrets')]
secrets-init:
    @bash "{{DOTFILES_DIR}}/scripts/load-secrets.sh" --init

# Push pass store to git remote
[group('secrets')]
secrets-push:
    @bash "{{DOTFILES_DIR}}/scripts/load-secrets.sh" --push

# Pull pass store from git remote
[group('secrets')]
secrets-pull:
    @bash "{{DOTFILES_DIR}}/scripts/load-secrets.sh" --pull

# Remove all dotfiles-managed symlinks, configs, and tools
[group('utils')]
[confirm("This will remove all dotfiles-managed state. Continue?")]
clean *FLAGS:
    @bash "{{DOTFILES_DIR}}/install/clean.sh" --yes {{FLAGS}}
