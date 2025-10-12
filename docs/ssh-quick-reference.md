# SSH YubiKey Quick Reference

## Server Commands (This Machine)

```bash
# Apply configuration (one-time setup)
sudo cp ~/.dotfiles/ssh/sshd_config_secure /etc/ssh/sshd_config.d/99-secure-external.conf
sudo systemctl restart ssh

# Check your IPs
echo "Local IP: $(hostname -I | awk '{print $1}')"
echo "External IP: $(curl -s https://api.ipify.org)"

# Monitor connections
sudo tail -f /var/log/auth.log
```

## Client Commands (Machine with YubiKey)

```bash
# One-time setup in ~/.bashrc or ~/.zshrc
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
export GPG_TTY=$(tty)
gpgconf --launch gpg-agent

# Connect to server
ssh -p 49152 beegass@<EXTERNAL-IP>
```

## Router Configuration
- **Port Forward**: External 49152 → Internal 49152 (TCP)
- **Internal IP**: Use server's local IP from above

## Troubleshooting
```bash
# On Client - YubiKey not working:
gpgconf --kill gpg-agent && gpgconf --launch gpg-agent
gpg --card-status

# On Server - Check if SSH is running:
sudo systemctl status ssh
sudo ss -tlnp | grep 49152
```