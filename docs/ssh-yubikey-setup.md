# SSH Access with YubiKey/GPG - Complete Setup Guide

## Overview
This guide sets up SSH access using GPG keys stored on YubiKey, with clear separation between:
- **SERVER**: The machine you want to SSH into (this computer)
- **CLIENT**: The machine you're connecting FROM (with YubiKey)

---

## SERVER SETUP (This Machine)

### 1. Install and Configure SSH Server

```bash
# Install OpenSSH server
sudo apt update
sudo apt install -y openssh-server

# Apply secure configuration
sudo cp ~/.dotfiles/ssh/sshd_config_secure /etc/ssh/sshd_config.d/99-secure-external.conf

# Test configuration
sudo sshd -t

# Restart SSH service
sudo systemctl restart ssh
sudo systemctl enable ssh
```

### 2. Verify Your GPG Key is in authorized_keys

```bash
# Check if your GPG auth key is already there
grep "openpgp:0x5F655FD2" ~/.ssh/authorized_keys

# If not found, export it from YubiKey (with YubiKey connected):
gpg --export-ssh-key 27D667E55F655FD2 >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### 3. Configure Firewall on Server

```bash
# Install and configure UFW
sudo apt install -y ufw

# Allow SSH on custom port
sudo ufw allow 49152/tcp

# Allow other services if needed (e.g., HTTP)
# sudo ufw allow 80/tcp
# sudo ufw allow 443/tcp

# Enable firewall
sudo ufw --force enable

# Check status
sudo ufw status
```

### 4. Get Server Information

```bash
# Get local IP (for router configuration)
hostname -I | awk '{print $1}'

# Get external IP (what clients will connect to)
curl -s https://api.ipify.org
echo  # New line

# Save these IPs:
echo "Local IP: $(hostname -I | awk '{print $1}')"
echo "External IP: $(curl -s https://api.ipify.org)"
```

### 5. Configure Router (Port Forwarding)

1. Open your router admin panel:
   - Usually at: `http://192.168.1.1` or `http://192.168.0.1`
   - Login with router credentials

2. Find "Port Forwarding" section (might be under):
   - Advanced Settings
   - NAT/Gaming
   - Virtual Server
   - Applications & Gaming

3. Create new port forwarding rule:
   ```
   Service Name: SSH-YubiKey
   External Port: 49152
   Internal Port: 49152
   Internal IP: [Your server's local IP from step 4]
   Protocol: TCP
   Enable: Yes
   ```

4. Save and apply settings

### 6. Optional: Setup Dynamic DNS

If you don't have a static IP, setup DuckDNS:

```bash
# Create DuckDNS directory
mkdir -p ~/duckdns
cd ~/duckdns

# Create update script (replace YOURDOMAIN and YOURTOKEN)
cat > duck.sh << 'EOF'
#!/bin/bash
DOMAIN="YOURDOMAIN"
TOKEN="YOURTOKEN"
curl -s "https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=" > ~/duckdns/duck.log
EOF

chmod 700 duck.sh

# Test it
./duck.sh
cat duck.log  # Should show "OK"

# Add to crontab for automatic updates
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -
```

### 7. Install Security Monitoring

```bash
# Install fail2ban to block brute force attempts
sudo apt install -y fail2ban

# Create SSH jail configuration
sudo tee /etc/fail2ban/jail.d/ssh-custom.conf << EOF
[sshd]
enabled = true
port = 49152
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

# Restart fail2ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
```

---

## CLIENT SETUP (Machine with YubiKey)

### 1. Install Required Software

```bash
# On Ubuntu/Debian:
sudo apt update
sudo apt install -y gnupg2 gpg-agent openssh-client

# On macOS:
brew install gnupg pinentry-mac
```

### 2. Configure GPG for SSH

```bash
# Create GPG agent configuration
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

# Configure gpg-agent for SSH support
cat > ~/.gnupg/gpg-agent.conf << EOF
enable-ssh-support
default-cache-ttl 1800
default-cache-ttl-ssh 1800
max-cache-ttl 7200
max-cache-ttl-ssh 7200
pinentry-program $(which pinentry-curses || which pinentry)
EOF

# On macOS, use:
# pinentry-program /usr/local/bin/pinentry-mac
```

### 3. Configure Shell for GPG-SSH

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# GPG SSH Configuration
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
export GPG_TTY=$(tty)

# Start gpg-agent if not running
gpgconf --launch gpg-agent

# Function to restart GPG agent if needed
gpg-restart() {
    gpgconf --kill gpg-agent
    gpgconf --launch gpg-agent
    echo "GPG agent restarted"
}
```

Then reload your shell:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

### 4. Test YubiKey Recognition

```bash
# Insert YubiKey and check it's recognized
gpg --card-status

# Should show your card details including:
# - Authentication key: 27D6 67E5 5F65 5FD2
# - Card serial number
# - Key attributes
```

### 5. Create SSH Config Entry

```bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config << EOF

# YubiKey SSH Server
Host myserver
    HostName YOUR_EXTERNAL_IP_OR_DOMAIN
    Port 49152
    User beegass
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_rsa_yubikey.pub
EOF

# Replace YOUR_EXTERNAL_IP_OR_DOMAIN with actual IP or domain
```

### 6. Test Connection

```bash
# First, verify GPG agent is running with SSH support
ssh-add -l
# Should show your GPG key

# Test connection
ssh -v -p 49152 beegass@YOUR_EXTERNAL_IP

# Or using the config alias:
ssh myserver
```

---

## TROUBLESHOOTING

### On Server:

```bash
# Check SSH service status
sudo systemctl status ssh

# Check SSH logs
sudo journalctl -u ssh -f

# Check auth logs
sudo tail -f /var/log/auth.log

# Test configuration
sudo sshd -t

# Check if port is listening
sudo ss -tlnp | grep 49152

# Check firewall
sudo ufw status verbose
```

### On Client:

```bash
# Check YubiKey is detected
gpg --card-status

# Check GPG agent
gpg-agent --version
echo $SSH_AUTH_SOCK

# List SSH keys available
ssh-add -l

# Restart GPG agent if needed
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

# Test with verbose output
ssh -vvv -p 49152 beegass@YOUR_EXTERNAL_IP

# Check if YubiKey is working
gpg --card-status | grep "Authentication key"
```

### Common Issues:

1. **"Permission denied (publickey)"**
   - YubiKey not inserted
   - GPG agent not running
   - Wrong SSH_AUTH_SOCK

2. **"Connection refused"**
   - Port forwarding not configured
   - Firewall blocking connection
   - SSH service not running

3. **"Connection timeout"**
   - ISP blocking port
   - Router firewall issue
   - Wrong external IP

4. **"Agent refused operation"**
   - YubiKey needs PIN
   - YubiKey locked (too many attempts)
   - GPG agent needs restart

---

## SECURITY CHECKLIST

- [ ] SSH running on non-standard port (49152)
- [ ] Password authentication disabled
- [ ] Root login disabled
- [ ] Firewall enabled and configured
- [ ] Fail2ban installed and active
- [ ] Only specific user allowed (beegass)
- [ ] Regular security updates applied
- [ ] Monitoring logs regularly

---

## QUICK REFERENCE

**Server**: 
```bash
sudo systemctl status ssh
sudo ufw status
sudo fail2ban-client status sshd
```

**Client**:
```bash
# Connect with YubiKey
ssh -p 49152 beegass@external-ip
```