#!/usr/bin/env bash
set -euo pipefail

APP="antigravity"
INSTALL_BASE="/opt"
CURRENT_LINK="${INSTALL_BASE}/${APP}-current"
BIN_LINK="/usr/local/bin/${APP}"

# Arch AUR package for Antigravity – used as "source of truth" for latest tarball URL
AUR_PAGE_URL="https://aur.archlinux.org/packages/antigravity"

log() { printf '[update-antigravity] %s\n' "$*" >&2; }

get_tarball_url_from_aur() {
  log "Fetching latest tarball URL from AUR (${AUR_PAGE_URL})..."
  local page
  if ! page="$(curl -fsSL "${AUR_PAGE_URL}")"; then
    log "ERROR: Failed to fetch AUR page."
    return 1
  fi

  # Grab the first Antigravity.tar.gz URL on the page
  local url
  url="$(printf '%s\n' "$page" | grep -oE 'https://[^"]*Antigravity\.tar\.gz' | head -n1 || true)"

  if [[ -z "$url" ]]; then
    log "ERROR: Could not find Antigravity.tar.gz URL on AUR page."
    return 1
  fi

  printf '%s\n' "$url"
}

cleanup_old_versions() {
  # keep = how many OLD versions (besides current) to keep
  local keep="${1:-0}"

  if ! [[ "$keep" =~ ^[0-9]+$ ]]; then
    log "Invalid keep count '$keep', skipping cleanup."
    return 0
  fi

  log "Cleaning up old ${APP} installs (keeping ${keep} old version(s) besides current)..."

  local current_dir=""
  current_dir="$(readlink -f "${CURRENT_LINK}" 2>/dev/null || true)"

  # Collect all antigravity-* dirs under INSTALL_BASE, sorted by version
  local -a all_dirs=()
  while IFS= read -r path; do
    all_dirs+=("$path")
  done < <(find "${INSTALL_BASE}" -maxdepth 1 -type d -name "${APP}-*" -printf '%p\n' | sort -V || true)

  if ((${#all_dirs[@]} == 0)); then
    log "No ${APP}-* directories found under ${INSTALL_BASE}, nothing to clean."
    return 0
  fi

  # Filter out the current dir from deletion candidates
  local -a candidates=()
  for d in "${all_dirs[@]}"; do
    if [[ -n "$current_dir" && "$d" == "$current_dir" ]]; then
      continue
    fi
    candidates+=("$d")
  done

  local total="${#candidates[@]}"
  if (( total <= keep )); then
    log "Found ${total} old install(s); keep=${keep}. Nothing to remove."
    return 0
  fi

  local to_delete=$(( total - keep ))
  log "Removing ${to_delete} oldest ${APP} install(s)..."

  for ((i=0; i<to_delete; i++)); do
    local dir="${candidates[i]}"
    log "  rm -rf ${dir}"
    sudo rm -rf "${dir}"
  done
}

main() {
  # How many old versions (besides current) to keep
  # DEFAULT: keep 0 old versions (only current)
  local keep_old="${AG_KEEP_VERSIONS:-0}"

  # Parse CLI args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep)
        if [[ $# -lt 2 ]]; then
          log "ERROR: --keep requires an argument"
          exit 1
        fi
        keep_old="$2"
        shift 2
        ;;
      --keep=*)
        keep_old="${1#*=}"
        shift
        ;;
      -*)
        log "ERROR: unknown option '$1'"
        exit 1
        ;;
      *)
        log "ERROR: unexpected positional argument '$1'"
        exit 1
        ;;
    esac
  done

  # 1) Decide tarball URL
  local tarball_url
  if [[ "${AG_TARBALL_URL-}" != "" ]]; then
    tarball_url="${AG_TARBALL_URL}"
    log "Using tarball URL from AG_TARBALL_URL:"
    log "  ${tarball_url}"
  else
    tarball_url="$(get_tarball_url_from_aur)"
    log "Found tarball URL:"
    log "  ${tarball_url}"
  fi

  # 2) Parse version from URL: .../stable/<version>/linux-x64/Antigravity.tar.gz
  local full_version
  full_version="$(printf '%s\n' "$tarball_url" \
    | sed -E 's#.*/stable/([^/]+)/linux-x64/Antigravity\.tar\.gz#\1#')"

  if [[ -z "$full_version" || "$full_version" == "$tarball_url" ]]; then
    log "ERROR: Could not parse version from tarball URL."
    exit 1
  fi

  local install_dir="${INSTALL_BASE}/${APP}-${full_version}"
  log "Resolved Antigravity version: ${full_version}"
  log "Target install dir: ${install_dir}"

  # 3) If already installed, just repoint symlinks
  if [[ -d "$install_dir" ]]; then
    log "Version already installed at ${install_dir}, skipping extraction."
  else
    # Download tarball to tmp
    local tmp_tar
    tmp_tar="$(mktemp "/tmp/${APP}.tar.XXXXXX")"
    log "Downloading tarball to ${tmp_tar}..."
    curl -fL "${tarball_url}" -o "${tmp_tar}"

    # Extract into /opt/antigravity-<full_version>
    log "Extracting into ${install_dir}..."
    sudo mkdir -p "${install_dir}"
    sudo tar xf "${tmp_tar}" -C "${install_dir}" --strip-components=1

    rm -f "${tmp_tar}"
  fi

  # 4) Update /opt/antigravity-current -> new version
  log "Updating ${CURRENT_LINK} -> ${install_dir}"
  sudo ln -sfn "${install_dir}" "${CURRENT_LINK}"

  # 5) Update /usr/local/bin/antigravity -> /opt/antigravity-current/antigravity
  log "Updating ${BIN_LINK} -> ${CURRENT_LINK}/antigravity"
  sudo ln -sfn "${CURRENT_LINK}/antigravity" "${BIN_LINK}"

  # 6) Show final state
  log "Final symlinks:"
  log "  $(readlink -f "${CURRENT_LINK}")"
  log "  $(readlink -f "${BIN_LINK}")"
  log "Installed Antigravity version (from URL/dir name): ${full_version}"

  # 7) Cleanup old installs
  cleanup_old_versions "${keep_old}"

  log "Done. If your .desktop Exec points at /opt/antigravity-current/antigravity, the icon now uses this version."
}

main "$@"
