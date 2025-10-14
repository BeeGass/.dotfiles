#!/usr/bin/env bash
set -euo pipefail

# Where your pics live (matches installer)
IMG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/neofetch/pics"

# Pick a random image if any exist
pick_image() {
  find "$IMG_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    2>/dev/null | shuf -n 1 || true
}

# Can we use kitty graphics *reliably* in this session?
kitty_usable() {
  # Only when terminal is Kitty OR WezTerm with Kitty passthrough, etc.
  [[ "${TERM:-}" == "xterm-kitty" || -n "${WEZTERM_EXECUTABLE-}" ]] || return 1
  # If inside tmux, require allow-passthrough and tmux >= 3.4
  if [[ -n "${TMUX-}" ]]; then
    local v pass
    v="$(tmux -V 2>/dev/null | awk '{print $2}')" || return 1
    pass="$(tmux show -gv allow-passthrough 2>/dev/null || true)"
    # numeric compare: ≥ 3.4
    awk -v ver="$v" 'BEGIN{
      split(ver,a,"."); m=a[1]+0; n=a[2]; sub(/[^0-9].*/,"",n); n+=0;
      exit !(m>3 || (m==3 && n>=4))
    }' </dev/null || return 1
    [[ "$pass" == "on" ]] || return 1
  fi
  return 0
}

# Choose the best backend with strong fallbacks
choose_backend() {
  # If Kitty + tmux passthrough is ready, use Kitty protocol
  if [[ "${TERM:-}" == "xterm-kitty" ]] && tmux_supports_passthrough; then
    # Nudge tmux to finalize terminal feature detection, then wait a beat
    tmux refresh-client -S >/dev/null 2>&1 || true
    sleep 0.15
    echo "kitty"; return
  fi

  # Crisp fallback hierarchy
  if command -v chafa >/dev/null 2>&1; then
    echo "chafa"; return
  fi
  if command -v w3mimgdisplay >/dev/null 2>&1; then
    echo "w3m"; return
  fi
  echo "ascii"
}

# Approximate image height == info height:
#   - Get line count of neofetch info
#   - Scale image width to roughly match that fraction of terminal height.
calc_size_percent() {
  local rows info_lines pct
  rows="$(tput lines 2>/dev/null || stty size 2>/dev/null | awk '{print $1}' || echo 24)"
  # Use --stdout to avoid drawing images during measurement
  info_lines="$(neofetch --stdout 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
  # Add a tiny margin; clamp to sane bounds
  pct="$(awk -v i="${info_lines:-10}" -v r="${rows:-24}" 'BEGIN{
    if (r<=0) r=24;
    p = (i+1) * 100.0 / r;
    if (p<10) p=10;
    if (p>80) p=80;
    printf("%.0f", p);
  }')"
  echo "${pct}%"
}

tmux_supports_passthrough() {
  [[ -z "${TMUX-}" ]] && return 1
  # tmux version >= 3.4?
  local v pass
  v="$(tmux -V 2>/dev/null | awk '{print $2}')" || return 1
  pass="$(tmux show -gv allow-passthrough 2>/dev/null || true)"
  awk -v ver="$v" 'BEGIN{split(ver,a,"."); m=a[1]+0; n=a[2]; sub(/[^0-9].*/,"",n); n+=0; exit !(m>3 || (m==3 && n>=4)) }' </dev/null || return 1
  [[ "$pass" == "on" ]]
}

main() {
  local img backend size
  img="$(pick_image)"
  backend="$(choose_backend)"

  # If no image or we’re ASCII-only, show plain neofetch
  if [[ -z "${img:-}" || "$backend" == "ascii" ]]; then
    neofetch
    exit 0
  fi

  # Compute size that roughly matches info height
  size="$(calc_size_percent)"

  # Draw using chosen backend; if it fails, fall back to ASCII cleanly
  case "$backend" in
    kitty)  neofetch --kitty  --source "$img" --size "$size" || neofetch ;;
    iterm)  neofetch --iterm  --source "$img" --size "$size" || neofetch ;;
    chafa)  neofetch --chafa  --source "$img" --size "$size" || neofetch ;;
    w3m)    neofetch --w3m    --source "$img" --size auto    || neofetch ;;
    *)      neofetch ;;
  esac
}

main "$@"
