# ~/.config/pfetch/presets/kiss_like.sh
# Clean, label/value column, no ASCII logo.
export PF_INFO="title os host kernel uptime pkgs memory wm shell editor palette"

unset PF_ASCII             # hide logo entirely
export PF_ALIGN=12         # column width for labels (tweak 10–14 to taste)
export PF_SEP="  "         # space between label and value
export PF_COLOR=1

# Colors: label, value, title. 3≈sand, 7≈white/bright gray.
export PF_COL1=3
export PF_COL2=7
export PF_COL3=7
