# Secrets management via pass (installed system-level in security.nix).
{ ... }:
{
  home.file.".password-store/.keep".text = "";
}
