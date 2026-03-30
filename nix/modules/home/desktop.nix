# Desktop environment modules (Niri + Wayland stack).
# Only imported by hosts with a desktop environment (manifold).
# NOT imported by headless servers (jacobian, hessian) or macOS (matrix).
{ ... }:
{
  imports = [
    ./desktop/niri.nix
    ./desktop/waybar.nix
    ./desktop/fuzzel.nix
    ./desktop/mako.nix
    ./desktop/swaylock.nix
    ./desktop/gtk-qt.nix
    ./desktop/desktop-apps.nix
  ];
}
