# Overlay aggregator.
# Custom packages and patches that aren't in nixpkgs.
final: prev: {
  # Google Sans Mono font (if not available in nixpkgs)
  # Uncomment and adjust the src path after cloning the font repo:
  #
  # google-sans-mono = prev.stdenvNoCC.mkDerivation {
  #   pname = "google-sans-mono";
  #   version = "1.0";
  #   src = /home/beegass/.local/share/fonts/google-sans-mono;
  #   installPhase = ''
  #     mkdir -p $out/share/fonts/truetype
  #     find . -name '*.ttf' -exec cp {} $out/share/fonts/truetype/ \;
  #   '';
  # };
}
