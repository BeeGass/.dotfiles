# Flatpak -- sandboxed application distribution
#
# Enables the Flatpak daemon and configures the system for installing
# Flatpak applications. Flatpak apps run in a sandboxed environment
# with controlled access to system resources via XDG portals.
#
# After the first boot, add the Flathub remote and install apps:
#
#   flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
#
# Recommended Flatpak apps (not declaratively managed -- install manually):
#
#   flatpak install flathub com.obsproject.Studio        # OBS Studio (streaming/recording)
#   flatpak install flathub com.spotify.Client            # Spotify
#   flatpak install flathub com.discordapp.Discord        # Discord
#   flatpak install flathub org.signal.Signal             # Signal Messenger
#   flatpak install flathub com.slack.Slack               # Slack
#   flatpak install flathub org.mozilla.Thunderbird       # Thunderbird (email)
#   flatpak install flathub com.bitwarden.desktop         # Bitwarden (passwords)
#   flatpak install flathub md.obsidian.Obsidian          # Obsidian (notes)
#   flatpak install flathub com.google.Chrome             # Google Chrome
#
{ config, lib, pkgs, ... }:

{
  services.flatpak.enable = true;
}
