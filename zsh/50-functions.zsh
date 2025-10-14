# ============================================================================
# Functions
# ============================================================================

# UV Python functions
uvnew() {
    if [ -z "$1" ]; then
        echo "Usage: uvnew <project-name> [python-version]"
        echo "Example: uvnew myproject 3.11"
        return 1
    fi

    local project_name="$1"
    local python_version="${2:-3.11}"

    mkdir -p "$project_name"
    cd "$project_name"
    uv init
    uv venv --python "$python_version"
    echo "Created new uv project: $project_name with Python $python_version"
}

uvsetup() {
    if [ -f "pyproject.toml" ]; then
        uv sync
        source .venv/bin/activate
        echo "Dependencies installed and virtual environment activated"
    else
        echo "No pyproject.toml found in current directory"
        return 1
    fi
}

uvupgrade() {
    if [ -f "pyproject.toml" ]; then
        echo "Syncing all extras and upgrading dependencies..."
        uv sync --all-extras && uv lock --upgrade
        echo "Dependencies upgraded and synced with all extras"
    else
        echo "No pyproject.toml found in current directory"
        return 1
    fi
}

# Git functions
allbranches() {
    git for-each-ref --format='%(refname:short)' refs/remotes | \
    while read remote; do
        git switch --create "${remote#origin/}" --track "$remote" 2>/dev/null
    done
}

gpgmsg() {
    if [ -z "$1" ]; then
        echo "Usage: gpgmsg <recipient_email>"
        return 1
    fi
    gpg -se -r "$1"
}

# SF Compute helpers (thin wrappers around the CLI)
sfssh()   { command sf vms ssh -A "$@"; }
sftunnel(){ command sftunnel "$@"; }  # script above will be on PATH via installer
