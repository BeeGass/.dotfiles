# Setting Up External SSH Access with YubiKey/GPG

## Prerequisites

- OpenSSH server installed (`sudo apt install openssh-server`)
- GPG key on YubiKey already in `~/.ssh/authorized_keys`
- Router/firewall access for port forwarding

## 1. Apply Secure SSH Configuration

```bash
# Copy the secure configuration
sudo cp ~/.dotfiles/ssh/sshd_config_secure /etc/ssh/sshd_config.d/99-secure-external.conf

# Test the configuration
sudo sshd -t

# Restart SSH service
sudo systemctl restart ssh
```

## 2. Configure Router/Firewall

### Port Forwarding

1. Access your router's admin panel (usually 192.168.1.1 or 192.168.0.1)
2. Find "Port Forwarding" or "Virtual Server" settings
3. Add a new rule:
   - External Port: 49152
   - Internal Port: 49152
   - Internal IP: Your server's local IP
   - Protocol: TCP

### Find Your Local IP

```bash
hostname -I | awk '{print $1}'
```

## 3. Set Up Dynamic DNS (if no static IP)

Options:

- **DuckDNS** (free): <https://www.duckdns.org>
- **No-IP** (free tier): <https://www.noip.com>
- **Cloudflare** (if you own a domain)

### Example with DuckDNS

```bash
# Install DuckDNS updater
mkdir ~/duckdns
cd ~/duckdns
echo "echo url=\"https://www.duckdns.org/update?domains=YOURDOMAIN&token=YOURTOKEN&ip=\" | curl -k -o ~/duckdns/duck.log -K -" > duck.sh
chmod 700 duck.sh

# Add to crontab
crontab -e
# Add: */5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```

## 4. Additional Security Measures

### Install Fail2Ban

```bash
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Configure Firewall (UFW)

```bash
# Install UFW
sudo apt install ufw

# Allow SSH on custom port
sudo ufw allow 49152/tcp

# Enable firewall
sudo ufw enable
```

### Monitor SSH Access

```bash
# Check auth logs
sudo tail -f /var/log/auth.log

# Check current connections
ss -tnp | grep :49152

# Check failed login attempts
sudo grep "Failed password" /var/log/auth.log
```

## 5. Connect from External Network

### From Client Machine

```bash
# Ensure YubiKey is connected
# Ensure GPG agent is running with SSH support
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent

# Connect using external IP or domain with custom port
ssh -p 49152 beegass@your-external-ip
# or
ssh -p 49152 beegass@yourdomain.duckdns.org
```

### Find Your External IP

```bash
curl -s https://api.ipify.org
# or
curl -s https://icanhazip.com
```

## 6. Troubleshooting

### Test Connection Locally First

```bash
ssh beegass@localhost
```

### Check SSH Service

```bash
sudo systemctl status ssh
sudo journalctl -u ssh -n 50
```

### Check Port is Open

```bash
# From external network
nc -zv your-external-ip 49152
```

### Common Issues

1. **Connection refused**: Check firewall and port forwarding
2. **Permission denied**: Check GPG agent is running and YubiKey is connected
3. **Timeout**: Check router settings and ISP blocking

## Security Notes

- Using port 49152 (non-standard) to reduce automated attacks
- Regularly check logs for suspicious activity
- Keep system and SSH updated
- Use fail2ban to block brute force attempts
- Never enable password authentication for external access
