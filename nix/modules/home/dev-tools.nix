# Developer tools and language runtimes.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Python
    uv
    python312

    # Rust (rustup manages toolchains in ~/.cargo)
    rustup

    # Node.js (system default; nvm can override per-project)
    nodejs_22

    # Build tools
    just
    gnumake
    gcc

    # Dev utilities (gh is in git.nix via programs.gh)
    pre-commit
  ];

  # uv tool installs for development
  home.activation.installUvTools = pkgs.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v uv &>/dev/null; then
      uv tool install python-lsp-server 2>/dev/null || true
      uv tool install ruff 2>/dev/null || true
      uv tool install mypy 2>/dev/null || true
      uv tool install pytest 2>/dev/null || true
    fi
  '';
}
