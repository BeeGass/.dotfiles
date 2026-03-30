# Mako notification daemon.
{ ... }:
{
  services.mako = {
    enable = true;
    settings = {
      font = "Google Sans Mono 10";
      background-color = "#1a1a1aee";
      text-color = "#ffffffff";
      border-color = "#333333ff";
      border-size = 2;
      border-radius = 8;
      width = 380;
      height = 120;
      padding = "12";
      margin = "8";
      anchor = "top-right";
      default-timeout = 5000;
      layer = "overlay";
      max-visible = 3;
      "[urgency=critical]" = {
        border-color = "#ff5252ff";
        default-timeout = 0;
      };
    };
  };
}
