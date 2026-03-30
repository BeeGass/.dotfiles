# Claude Code configuration and Remote Control services.
# Settings are symlinked (JSON/markdown, not system config).
{ config, pkgs, lib, ... }:

let
  link = config.lib.file.mkOutOfStoreSymlink;
  dotfiles = "${config.home.homeDirectory}/.dotfiles";

  mkClaudeRC = name: displayName: workDir: {
    Unit = {
      Description = "Claude Code Remote Control - ${displayName}";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${config.home.homeDirectory}/.local/bin/claude remote-control --name \"${displayName}\"";
      WorkingDirectory = workDir;
      Environment = [
        "PATH=${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin"
        "NODE_OPTIONS=--max-old-space-size=4096"
      ];
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
in
{
  # Symlink Claude Code configuration files
  home.file.".claude/settings.json".source = link "${dotfiles}/claude/settings.json";
  home.file.".claude/CLAUDE.md".source = link "${dotfiles}/claude/CLAUDE.md";
  home.file.".claude/.mcp.json".source = link "${dotfiles}/claude/.mcp.json";
  home.file.".claude/commands".source = link "${dotfiles}/claude/commands";
  home.file.".claude/rules".source = link "${dotfiles}/claude/rules";
  home.file.".claude/reference".source = link "${dotfiles}/claude/reference";
  home.file.".claude/statusline".source = link "${dotfiles}/claude/statusline";
  xdg.configFile."claude/CLAUDE.md".source = link "${dotfiles}/claude/CLAUDE.md";

  # Gemini CLI config
  xdg.configFile."gemini/GEMINI.md".source = link "${dotfiles}/gemini/GEMINI.md";

  # Claude Remote Control systemd user services (Linux only -- macOS uses launchd)
  systemd.user.services = lib.mkIf pkgs.stdenv.isLinux {
    claude-rc-manifold  = mkClaudeRC "manifold"  "Manifold"          config.home.homeDirectory;
    claude-rc-projects  = mkClaudeRC "projects"  "Manifold Projects" "${config.home.homeDirectory}/Projects";
    claude-rc-freectrl  = mkClaudeRC "freectrl"  "Manifold FreeCtrl" "${config.home.homeDirectory}/Projects/FreeCtrl";
    claude-rc-rsde      = mkClaudeRC "rsde"      "Manifold RSDE"     "${config.home.homeDirectory}/Projects/RSDE";
  };
}
