# Jacobian Setup (RPi 5 -- Key Server)

This guide covers setting up Jacobian (Raspberry Pi 5) as a dedicated key server for the dotfiles ecosystem. Once configured, all other machines can fetch API keys over SSH without storing them on disk.

## Prerequisites

* Jacobian is accessible via Tailscale (hostname: `Jacobian`, or `Jacobian.tailf7d439.ts.net`)
* SSH access is configured with YubiKey-only authentication (see `docs/ssh-yubikey-setup.md`)
* The dotfiles are installed on Jacobian (`chezmoi init --apply BeeGass/.dotfiles`)

## 1. Create the key directory

```bash
ssh Jacobian

mkdir -p ~/.secrets
chmod 700 ~/.secrets
```

## 2. Create the key file

```bash
cat > ~/.secrets/env <<'EOF'
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export GEMINI_API_KEY=...
export HF_TOKEN=hf_...
EOF

chmod 600 ~/.secrets/env
```

Add any additional keys as `export KEY=value` lines. The file is sourced directly by the SSH fallback path, so the format must be valid shell.

## 3. Verify permissions

```bash
ls -la ~/.secrets/
# drwx------ 2 beegass beegass 4096 ... .secrets
# -rw------- 1 beegass beegass  ... ... env

# Verify no other users can read
stat -c '%a %U' ~/.secrets ~/.secrets/env
# 700 beegass
# 600 beegass
```

## 4. Test from a client machine

From any machine on the Tailscale network:

```bash
# Test SSH connectivity
ssh -o ConnectTimeout=5 -o BatchMode=yes Jacobian "echo ok"

# Test retrieval
ssh Jacobian "cat ~/.secrets/env"

# Test via load-secrets
load-secrets --check
```

## 5. (Optional) Set up pass store sync

If you want to sync your `pass` store to a private git remote so all machines share the same encrypted entries:

```bash
# On any machine with pass initialized
load-secrets --init                      # if not already done
pass git remote add origin git@github.com:BeeGass/pass-store.git
pass git push -u origin main

# On other machines
git clone git@github.com:BeeGass/pass-store.git ~/.password-store
```

The pass store is GPG-encrypted, so the git remote can be private or even hosted on Jacobian itself.

## Architecture

```
                    Tailscale Network
                          |
     +--------------------+--------------------+
     |                    |                    |
  Manifold             Tensor              HPC Cluster
  (pass+GPG)          (pass+GPG)          (SSH only)
     |                    |                    |
     +--------------------+--------------------+
                          |
                      Jacobian
                    (RPi 5, key server)
                    ~/.secrets/env
```

### How each machine loads keys

| Machine | Primary method | Fallback |
|---------|---------------|----------|
| Manifold / Tensor | `pass` (GPG, YubiKey) | SSH to Jacobian |
| macOS laptop | `pass` (GPG, YubiKey) | SSH to Jacobian |
| HPC cluster | SSH to Jacobian | -- |
| Termux | SSH to Jacobian | -- |

### Security layers

| Layer | Protection |
|-------|-----------|
| SSH transport | Encrypted; YubiKey-only auth via `99-yubikey-only.conf` |
| Tailscale network | WireGuard encrypted; ACL-controlled access |
| File permissions | `700`/`600`; only the `beegass` user can read |
| Pass store (clients) | AES-256 via GPG; requires YubiKey touch to decrypt |
| HPC access | SSH tunnel through Tailscale; keys exist only in memory |

Keys never exist in plaintext on any machine except Jacobian. On home machines using `pass`, keys are GPG-encrypted at rest and only decrypted into memory when the YubiKey is physically present and touched.

## Adding or rotating keys

```bash
# On Jacobian: edit the file directly
ssh Jacobian
vim ~/.secrets/env

# In the pass store: update the encrypted entry
pass edit api/OPENAI_API_KEY

# Sync the pass store
load-secrets --push
```

After updating, run `load-secrets` on each machine to pick up the new values. There is no automatic propagation -- keys are loaded on demand.

## Troubleshooting

### Cannot connect to Jacobian

```bash
# Check Tailscale status
tailscale status | grep -i jacobian

# Check SSH config
ssh -vvv Jacobian "true"

# Ensure Jacobian is powered on and connected to the network
```

### Pass decryption fails

```bash
# Check if YubiKey is detected
gpg --card-status

# Restart GPG agent
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

# Check pass store
pass ls api/
```

### Keys not loading on HPC

HPC clusters use SSH-only fallback. Ensure:

1. The HPC can reach Jacobian (may need a Tailscale exit node or SSH jump host)
2. SSH keys are forwarded or available: `ssh -o BatchMode=yes Jacobian "true"`
3. If direct access is blocked, set up a tunnel:

```bash
# From a machine that can reach both HPC and Jacobian
ssh -L 2222:Jacobian:40822 manifold

# Then on HPC
SECRETS_HOST=localhost load-secrets
```
