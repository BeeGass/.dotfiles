# Vector

Portable SSH client. Google Pixel Fold 2 running Android, used for on-the-go access to the homelab via Tailscale + Termux (sshd on port 40822).

## Hardware

| Component | Spec |
|-----------|------|
| Device | Google Pixel Fold 2 |
| Form factor | Foldable phone |
| OS | Android |
| Architecture | aarch64-linux (via Termux) |

## Network

| Field | Value |
|-------|-------|
| SSH | `ssh Vector` |
| Tailscale | vector.tailf7d439.ts.net |
| SSH Port | 40822 |
| User | beegass |

## Role

- Portable SSH client for reaching the homelab from anywhere
- Termux provides a full shell environment (zsh, git, ssh)
- Runs Termux sshd on port 40822 so other homelab hosts can reach it over Tailscale
- YubiKey NFC used for SSH auth (gpg-agent on this host, or OpenKeychain)
