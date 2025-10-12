#!/usr/bin/env bash
set -euo pipefail

LABEL="dev.onlygass.cfddns"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="${SRC_DIR}/ssh/cf-ddns.sh"
ENV_SRC="${SRC_DIR}/ssh/cf-ddns.env"

SCRIPT_DST="/usr/local/bin/cf-ddns.sh"
ENV_DST="/etc/cf-ddns.env"
PLIST_DST="/Library/LaunchDaemons/${LABEL}.plist"
OUT_LOG="/var/log/cf-ddns.log"
ERR_LOG="/var/log/cf-ddns.err"

need() { command -v "$1" >/dev/null 2>&1; }

# ---- pre-checks (as your user, not root) ----
[[ -f "$SCRIPT_SRC" ]] || { echo "Missing $SCRIPT_SRC"; exit 1; }
[[ -f "$ENV_SRC" ]]   || { echo "Missing $ENV_SRC"; exit 1; }

# jq needed by your updater script
if ! need jq; then
  if need brew; then
    echo "Installing jq with Homebrew..."
    brew install jq
  else
    echo "jq not found and Homebrew not installed."
    echo "Install Homebrew (https://brew.sh) then run: brew install jq"
    exit 1
  fi
fi

# ---- escalate to root for system install ----
if [[ $EUID -ne 0 ]]; then
  echo "Re-running with sudo..."
  exec sudo "$0" "$@"
fi

echo "Installing cf-ddns script and config..."
install -m 755 "$SCRIPT_SRC" "$SCRIPT_DST"
install -m 600 "$ENV_SRC"   "$ENV_DST"
chown root:wheel "$ENV_DST"

# sanity check required vars in env
for v in CF_API_TOKEN ZONE_NAME RECORD_NAME; do
  if ! grep -Eq "^\s*$v=.+$" "$ENV_DST"; then
    echo "WARNING: $v not set in $ENV_DST"
  fi
done

echo "Writing LaunchDaemon plist..."
cat > "$PLIST_DST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.onlygass.cfddns</string>
  <key>UserName</key><string>root</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/cf-ddns.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>KeepAlive</key>
  <dict><key>NetworkState</key><true/></dict>
  <key>StartInterval</key><integer>300</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/var/log/cf-ddns.log</string>
  <key>StandardErrorPath</key><string>/var/log/cf-ddns.err</string>
</dict>
</plist>
PLIST

chown root:wheel "$PLIST_DST"
chmod 644 "$PLIST_DST"

# ensure logs exist
touch "$OUT_LOG" "$ERR_LOG"
chown root:wheel "$OUT_LOG" "$ERR_LOG"
chmod 644 "$OUT_LOG" "$ERR_LOG"

echo "Running updater once..."
/usr/local/bin/cf-ddns.sh || true

echo "Loading LaunchDaemon..."
launchctl unload -w "$PLIST_DST" 2>/dev/null || true
launchctl load -w "$PLIST_DST"
launchctl kickstart -k "system/${LABEL}" || true

echo "All set ✅"
echo "Logs: tail -f $OUT_LOG $ERR_LOG"
