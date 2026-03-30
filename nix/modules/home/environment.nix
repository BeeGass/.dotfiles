# Session environment variables and PATH.
{ ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    CLAUDE_CODE_MAX_OUTPUT_TOKENS = "64000";
    BAT_THEME = "TwoDark";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
  ];
}
