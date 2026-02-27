# Dotfiles management via chezmoi
# =================================
# Run `just --list` to see all available recipes grouped by category.
# Run `just <recipe>` to execute a specific task.

set shell := ["bash", "-euo", "pipefail", "-c"]

export DOTFILES_DIR := env_var_or_default("DOTFILES_DIR", home_directory() + "/.dotfiles")

# List all available recipes
default:
    @just --list --unsorted

# ------------------------------------------------------------------------------
# Chezmoi core operations
# ------------------------------------------------------------------------------

# Apply dotfiles to this machine
[group('chezmoi')]
apply:
    chezmoi apply

# Pull latest and apply
[group('chezmoi')]
update:
    chezmoi update

# Show what would change
[group('chezmoi')]
diff:
    chezmoi diff

# Show managed file status
[group('chezmoi')]
status:
    chezmoi status

# Edit a chezmoi-managed file (opens source + target)
[group('chezmoi')]
edit file:
    chezmoi edit {{file}}

# Re-add modified target files back to chezmoi source
[group('chezmoi')]
sync:
    chezmoi re-add

# Bootstrap on a fresh machine
[group('chezmoi')]
bootstrap:
    chezmoi init --apply BeeGass/.dotfiles

# Force re-run one-time scripts (after script changes)
[group('chezmoi')]
rerun-scripts:
    chezmoi state delete-bucket --bucket=scriptState
    chezmoi apply

# Run chezmoi diagnostics
[group('chezmoi')]
chezmoi-doctor:
    chezmoi doctor

# Dry-run apply (show what would change without modifying)
[group('chezmoi')]
dry-run:
    chezmoi apply --dry-run --verbose

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
# Secrets
# ------------------------------------------------------------------------------

# Check secrets connectivity (pass store + SSH fallback)
[group('secrets')]
secrets-check:
    @bash "{{DOTFILES_DIR}}/scripts/load-secrets.sh" --check

# Load secrets into current session
[group('secrets')]
secrets-load:
    @bash "{{DOTFILES_DIR}}/scripts/load-secrets.sh"

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
