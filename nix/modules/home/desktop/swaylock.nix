# Swaylock screen locker with effects (blur, clock).
{ pkgs, ... }:
{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      screenshots = true;
      clock = true;
      indicator = true;
      indicator-radius = 120;
      indicator-thickness = 8;
      effect-blur = "10x5";
      effect-vignette = "0.5:0.5";
      grace = 3;
      fade-in = 0.2;

      inside-color = "1a1a1a00";
      ring-color = "333333ff";
      key-hl-color = "f7ca88ff";
      bs-hl-color = "ff5252ff";
      separator-color = "00000000";
      inside-ver-color = "1a1a1a00";
      ring-ver-color = "9d7cd8ff";
      inside-wrong-color = "1a1a1a00";
      ring-wrong-color = "ff5252ff";

      text-color = "ffffffff";
      text-ver-color = "9d7cd8ff";
      text-wrong-color = "ff5252ff";

      font = "Google Sans Mono";
      font-size = 24;
      timestr = "%l:%M %p";
      datestr = "%A, %B %d";
    };
  };
}
