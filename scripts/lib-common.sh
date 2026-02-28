#!/usr/bin/env bash
# lib-common.sh - Shared logging and helper functions for dotfiles scripts
# Source this file from chezmoi scripts and utility scripts.

[[ -n "${_DOTFILES_LIB_COMMON_LOADED:-}" ]] && return 0
_DOTFILES_LIB_COMMON_LOADED=1

# === Colors and Logging ===
_use_color=1
if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then _use_color=0; fi

if [[ $_use_color -eq 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
  DIM=$(tput dim)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
else
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  MAGENTA=$'\033[35m'
  CYAN=$'\033[36m'
  [[ $_use_color -eq 0 ]] && BOLD='' && RESET='' && DIM='' && RED='' && GREEN='' && YELLOW='' && BLUE='' && MAGENTA='' && CYAN=''
fi

section() { printf "%s==>%s %s%s%s\n" "$CYAN$BOLD" "$RESET" "$BOLD" "$*" "$RESET"; }
step() { printf "  %s->%s %s\n" "$BLUE$BOLD" "$RESET" "$*"; }
ok() { printf "  %s[ok]%s %s\n" "$GREEN$BOLD" "$RESET" "$*"; }
warn() { printf "  %s[warn]%s %s\n" "$YELLOW$BOLD" "$RESET" "$*"; }
err() { printf "  %s[err ]%s %s\n" "$RED$BOLD" "$RESET" "$*"; }
note() { printf "  %s%s%s\n" "$DIM" "$*" "$RESET"; }

have() { command -v "$1" >/dev/null 2>&1; }
have_apt() { have apt-get || have apt; }

detect_os() {
  if [[ -n "${TERMUX_VERSION-}" ]] || [[ "${PREFIX-}" == *"com.termux"* ]]; then
    echo "Termux"
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "Linux"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macOS"
  else
    echo "Unknown"
  fi
}
