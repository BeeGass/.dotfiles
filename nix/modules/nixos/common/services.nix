# System services: OpenSSH, fwupd, locale, timezone.
{ vars, ... }:
{
  # -- OpenSSH --
  services.openssh = {
    enable = true;
    ports = [ vars.networking.sshPort ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      MaxAuthTries = 3;
      StreamLocalBindUnlink = true;
      AllowAgentForwarding = true;
    };
  };

  # -- Firmware updates --
  services.fwupd.enable = true;

  # -- Timezone and Locale --
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
