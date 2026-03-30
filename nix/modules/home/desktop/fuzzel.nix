# Fuzzel app launcher.
{ ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "Google Sans Mono:size=12";
        terminal = "ghostty -e";
        prompt = ">  ";
        width = 40;
        lines = 12;
        horizontal-pad = 20;
        vertical-pad = 12;
        border-width = 2;
        border-radius = 8;
        layer = "overlay";
      };
      colors = {
        background = "1a1a1aee";
        text = "ffffffff";
        selection = "f7ca88ff";
        selection-text = "1a1a1aff";
        border = "333333ff";
        match = "f7ca88ff";
        selection-match = "1a1a1aff";
      };
    };
  };
}
