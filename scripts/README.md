# Scripts

install_cf_ddns_macos.sh - Install Cloudflare DDNS upate script (macOS)
```bash
chmod +x ./install_cf_ddns_macos.sh
./install_cf_ddns_macos.sh
```

unistall (optional) - Uninstall Cloudflare DDNS update script (macOS)
```bash
sudo launchctl unload -w /Library/LaunchDaemons/dev.onlygass.cfddns.plist
sudo rm -f /Library/LaunchDaemons/dev.onlygass.cfddns.plist
sudo rm -f /usr/local/bin/cf-ddns.sh /etc/cf-ddns.env
sudo rm -f /var/log/cf-ddns.log /var/log/cf-ddns.err
```
