# Desktop application configuration (Flatpak, MIME, Wayland flags).
{ config, pkgs, ... }:
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "google-chrome.desktop" ];
      "x-scheme-handler/http" = [ "google-chrome.desktop" ];
      "x-scheme-handler/https" = [ "google-chrome.desktop" ];
      "application/pdf" = [ "org.gnome.Evince.desktop" ];
    };
  };

  # Flatpak apps installed after first boot:
  # flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  # flatpak install flathub md.obsidian.Obsidian
  # flatpak install flathub com.discordapp.Discord
  # flatpak install flathub com.google.Chrome
  # flatpak install flathub org.telegram.desktop
  # flatpak install flathub com.spotify.Client
  # flatpak install flathub com.slack.Slack

  # VS Code with explicit Wayland flags
  xdg.desktopEntries.code-wayland = {
    name = "Visual Studio Code (Wayland)";
    exec = "code --enable-features=UseOzonePlatform --ozone-platform=wayland";
    icon = "visual-studio-code";
    terminal = false;
    categories = [ "Development" "IDE" ];
  };
}
