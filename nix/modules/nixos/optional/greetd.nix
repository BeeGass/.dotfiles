# greetd -- minimal login manager with tuigreet TUI greeter
#
# Provides a clean terminal-based login screen on tty1 that lists
# available Wayland sessions (niri, etc.) and remembers the last
# selected user and session.
{ config, lib, pkgs, ... }:

{
  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        # tuigreet: terminal UI greeter for greetd
        #   --time           show current time on the greeter screen
        #   --asterisks      show asterisks when typing the password
        #   --remember       remember the last selected session
        #   --remember-user-session  remember per-user session choice
        #   --sessions       path to .desktop files for Wayland sessions
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-user-session --sessions /etc/greetd/wayland-sessions";

        # Run the greeter as the unprivileged "greeter" user (created
        # automatically by the greetd NixOS module).
        user = "greeter";
      };
    };
  };

  # Suppress kernel and systemd boot messages on tty1 so the greeter
  # starts with a clean screen. Without this, boot logs scroll over
  # the login prompt until the user presses a key.
  systemd.services.greetd.serviceConfig = {
    Type = "idle";

    # StandardInput/Output ensure greetd owns tty1 cleanly
    StandardInput = "tty";
    StandardOutput = "tty";

    # Prevent kernel messages from spilling onto the greeter tty
    TTYVTDisallocate = true;
  };
}
