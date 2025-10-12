#!/usr/bin/env bash
set -euo pipefail

# Define the directory for neofetch images, respecting XDG standards
img_dir="${XDG_DATA_HOME:-$HOME/.local/share}/neofetch/pics"

# Enable recursive globbing and prevent errors if no files are found
shopt -s globstar nullglob

# Find all image files and store them in an array
files=("$img_dir"/**/*.{png,jpg,jpeg,webp,gif})

# If no image files are found, run neofetch without image support and exit
if [[ ${#files[@]} -eq 0 ]]; then
    exec neofetch "$@"
fi

# Select a random image from the array
img="${files[RANDOM % ${#files[@]}]}"

# Determine the best available image backend
backend="ascii" # Default backend
if command -v chafa >/dev/null; then
    backend="chafa"
fi
# Prefer w3m if available and not inside a TMUX session
if command -v w3mimgdisplay >/dev/null && [[ -z "${TMUX-}" ]]; then
    backend="w3m"
fi

# Execute neofetch with the chosen image, backend, and any passthrough arguments
exec neofetch --image_backend "$backend" --source "$img" --image_size 35% "$@"
