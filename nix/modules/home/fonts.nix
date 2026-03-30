# Font packages and fontconfig.
# Translates: fontconfig/30-google-sans-mono-mono.conf
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    # Google Sans Mono: if not in nixpkgs, use the overlay in overlays/default.nix
  ];

  # Force Google Sans Mono to be recognized as monospaced
  xdg.configFile."fontconfig/conf.d/30-google-sans-mono-mono.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <match target="scan">
        <test name="family" compare="eq"><string>Google Sans Mono</string></test>
        <edit name="spacing" mode="assign"><int>100</int></edit>
      </match>
    </fontconfig>
  '';
}
