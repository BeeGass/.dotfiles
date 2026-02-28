#!/usr/bin/env bash
set -euo pipefail

APP="antigravity"
INSTALL_BASE="/opt"
CURRENT_LINK="${INSTALL_BASE}/${APP}-current"
BIN_LINK="/usr/local/bin/${APP}"

# Official Google apt repository for Antigravity
APT_REPO_BASE="https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev"
PACKAGES_URL="${APT_REPO_BASE}/dists/antigravity-debian/main/binary-amd64/Packages"

log() { printf '[update-antigravity] %s\n' "$*" >&2; }

get_deb_info_from_repo() {
  log "Fetching package info from apt repository..."
  local packages
  if ! packages="$(curl -fsSL "${PACKAGES_URL}")"; then
    # Try .gz version if uncompressed fails
    if ! packages="$(curl -fsSL "${PACKAGES_URL}.gz" | gunzip)"; then
      log "ERROR: Failed to fetch Packages file from apt repo."
      return 1
    fi
  fi

  # Extract all versions and filenames, then get the latest (last entry when sorted by version)
  local version filename
  version="$(printf '%s\n' "$packages" | grep -E '^Version:' | awk '{print $2}' | sort -V | tail -n1)"

  # Get the filename for the latest version by finding the block with that version
  filename="$(printf '%s\n' "$packages" | awk -v ver="$version" '
    /^Package:/ { pkg_block = "" }
    { pkg_block = pkg_block $0 "\n" }
    /^Version:/ && $2 == ver { found = 1 }
    /^Filename:/ && found { print $2; found = 0; exit }
  ')"

  if [[ -z "$version" || -z "$filename" ]]; then
    log "ERROR: Could not parse version/filename from Packages file."
    return 1
  fi

  # Output version and full URL
  printf '%s\n' "$version"
  printf '%s\n' "${APT_REPO_BASE}/${filename}"
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
  if ((total <= keep)); then
    log "Found ${total} old install(s); keep=${keep}. Nothing to remove."
    return 0
  fi

  local to_delete=$((total - keep))
  log "Removing ${to_delete} oldest ${APP} install(s)..."

  for ((i = 0; i < to_delete; i++)); do
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

  # 1) Get version and .deb URL from apt repository
  local deb_info full_version deb_url
  if [[ "${AG_DEB_URL-}" != "" ]]; then
    deb_url="${AG_DEB_URL}"
    # Parse version from provided URL
    full_version="$(printf '%s\n' "$deb_url" \
      | sed -E 's#.*/antigravity_([0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?)_amd64\.deb#\1#')"
    log "Using .deb URL from AG_DEB_URL:"
    log "  ${deb_url}"
  else
    deb_info="$(get_deb_info_from_repo)"
    full_version="$(printf '%s\n' "$deb_info" | sed -n '1p')"
    deb_url="$(printf '%s\n' "$deb_info" | sed -n '2p')"
    log "Found version: ${full_version}"
    log "Found .deb URL: ${deb_url}"
  fi

  if [[ -z "$full_version" ]]; then
    log "ERROR: Could not determine version."
    exit 1
  fi

  # Strip debian revision (e.g., 1.14.2-1768287740 -> 1.14.2) for directory name
  local short_version="${full_version%%-*}"
  local install_dir="${INSTALL_BASE}/${APP}-${short_version}"
  log "Target install dir: ${install_dir}"

  # 2) If already installed, just repoint symlinks
  if [[ -d "$install_dir" ]]; then
    log "Version already installed at ${install_dir}, skipping extraction."
  else
    # Download .deb to tmp
    local tmp_deb tmp_extract
    tmp_deb="$(mktemp "/tmp/${APP}.deb.XXXXXX")"
    tmp_extract="$(mktemp -d "/tmp/${APP}.extract.XXXXXX")"
    log "Downloading .deb to ${tmp_deb}..."
    curl -fL "${deb_url}" -o "${tmp_deb}"

    # Extract .deb (ar archive containing data.tar.*)
    log "Extracting .deb..."
    cd "${tmp_extract}"
    ar x "${tmp_deb}"

    # Extract data.tar.* (could be .xz, .zst, .gz)
    local data_tar
    data_tar="$(ls data.tar.* 2>/dev/null | head -n1)"
    if [[ -z "$data_tar" ]]; then
      log "ERROR: No data.tar.* found in .deb"
      rm -rf "${tmp_deb}" "${tmp_extract}"
      exit 1
    fi

    log "Extracting ${data_tar} into ${install_dir}..."
    sudo mkdir -p "${install_dir}"
    sudo tar xf "${data_tar}" -C "${install_dir}" --strip-components=4 ./usr/share/antigravity

    rm -rf "${tmp_deb}" "${tmp_extract}"
    cd - >/dev/null
  fi

  # 3) Update /opt/antigravity-current -> new version
  log "Updating ${CURRENT_LINK} -> ${install_dir}"
  sudo ln -sfn "${install_dir}" "${CURRENT_LINK}"

  # 4) Update /usr/local/bin/antigravity -> /opt/antigravity-current/antigravity
  log "Updating ${BIN_LINK} -> ${CURRENT_LINK}/antigravity"
  sudo ln -sfn "${CURRENT_LINK}/antigravity" "${BIN_LINK}"

  # 5) Show final state
  log "Final symlinks:"
  log "  $(readlink -f "${CURRENT_LINK}")"
  log "  $(readlink -f "${BIN_LINK}")"
  log "Installed Antigravity version: ${short_version}"

  # 6) Cleanup old installs
  cleanup_old_versions "${keep_old}"

  log "Done. If your .desktop Exec points at /opt/antigravity-current/antigravity, the icon now uses this version."
}

main "$@"
