# NixOS First-Boot Runbook

Applies to **Tensor (Phase 6)** and **Manifold (Phase 8)** of the migration plan at `claude/plans/im-about-to-begin-swift-blum.md`. The pre-wipe checklist runs on the current Ubuntu host BEFORE booting the NixOS installer; the first-boot steps run on the new NixOS install.

---

## Pre-wipe checklist

Snapshot hardware state and back up everything irreplaceable.

```sh
mkdir -p ~/migration-snapshot

# Hardware/system snapshots
lsblk -f                                       > ~/migration-snapshot/lsblk.txt
sudo blkid                                     > ~/migration-snapshot/blkid.txt
nvidia-smi -q                                  > ~/migration-snapshot/nvidia-smi.txt
ip -br addr                                    > ~/migration-snapshot/network.txt
cat /etc/fstab                                 > ~/migration-snapshot/fstab.txt
dpkg --get-selections | grep -v deinstall      > ~/migration-snapshot/apt-packages.txt
flatpak list --app 2>/dev/null                 > ~/migration-snapshot/flatpak.txt
crontab -l 2>/dev/null                         > ~/migration-snapshot/cron.txt
systemctl list-unit-files --user --state=enabled > ~/migration-snapshot/user-units.txt

# Sizes — capacity-gate input for Phase 7
sudo du -shx /data /home/$(whoami) ~/.gnupg ~/.password-store ~/.ssh 2>/dev/null \
  | tee ~/migration-snapshot/sizes.txt
```

Confirm before continuing:

- [ ] `/data` rsynced to the holding location (Phase 7 stages it on Tensor)
- [ ] `~/.ssh/`, `~/.gnupg/` (private keys + revocation certs), `~/.password-store/` backed up
- [ ] All uncommitted work in `~/Projects/` pushed (`git status` clean in every repo) or rsynced as part of /home
- [ ] YubiKey recovery PIN/PUK accessible offline (YubiKey can lock out)
- [ ] Tailscale auth key/login email at hand for first-boot rejoin
- [ ] NixOS unstable ISO on a tested USB stick
- [ ] Pro 6000 power-connector compatibility verified vs PSU (only for Phase 10 swap)

---

## First boot — common to all hosts

After `nixos-install`, reboot pulls USB, and you log into greetd/tuigreet → niri session.

### 1. Verify NVIDIA driver loaded

```sh
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv
```

Expected results by phase:

| Phase | Host | Expected device | Compute cap |
|---|---|---|---|
| 6 | Tensor | GeForce RTX 3080 | 8.6 (Ampere) |
| 8 | Manifold | GeForce RTX 5090 | 12.0 (Blackwell) |
| 10 | Manifold | NVIDIA RTX Pro 6000 | 12.0 (Blackwell) |
| 11 | Tensor | GeForce RTX 5090 | 12.0 (Blackwell) |

### 2. YubiKey GPG bootstrap (one-time, interactive)

```sh
~/.local/bin/setup_gpg_ssh.sh --regen
# Prompts for YubiKey touch. Imports pubkey from GitHub, links gpg-agent SSH socket.

# Verify:
gpg --card-status        # shows YubiKey serial + key info
ssh-add -L               # shows YubiKey-backed SSH key
ssh -T git@github.com    # should authenticate
```

### 3. Pass store init + sync from Jacobian

```sh
# Initialize on the new host (uses the GPG-id from your YubiKey).
pass init 0xACC3640C138D96A2

# Clone the pass-store git remote from Jacobian.
ssh Jacobian "cat ~/.password-store/.git/config"   # confirm remote
cd ~ && git clone ubuntu@Jacobian:/home/ubuntu/.password-store .password-store

# Or use justfile shortcuts:
just secrets-init
just secrets-pull
load-secrets    # confirms env vars source successfully
```

### 4. Seed `~/.dotfiles/zsh/90-local.zsh` (NON-SECRET paths only)

**Policy:** `90-local.zsh` is gitignored but lives inside the dotfiles repo. **API keys, tokens, and other secrets MUST NOT live here.** Secrets go through `pass` + `load-secrets`.

```sh
cat > ~/.dotfiles/zsh/90-local.zsh <<'EOF'
# Machine-local zsh overrides. NOT COMMITTED (per .gitignore).
# Sourced by zsh/zshrc near the end. Non-secret paths only.
#
# SECRETS POLICY: API keys and tokens are loaded via `load-secrets` from the
# pass store. Run `load-secrets` in any shell that needs them.

# Hugging Face cache + datasets root (also system sessionVariables; redundant
# for tools that read shell init like some IDE terminals).
export HF_HOME="/data/hf-cache"
export HF_HUB_CACHE="/data/hf-cache/hub"
export TRANSFORMERS_CACHE="/data/hf-cache"
export DATASETS_ROOT="/data/datasets"
export MODELS_ROOT="/data/models"
export CHECKPOINTS_ROOT="/data/checkpoints"
export SCRATCH_ROOT="/data/scratch"

# OpenCode CLI (installed manually, not in nixpkgs)
export PATH="$HOME/.opencode/bin:$PATH"

# Local LLM endpoints (uncomment if running ollama/llama.cpp locally)
# export OLLAMA_HOST="http://localhost:11434"
EOF
chmod 644 ~/.dotfiles/zsh/90-local.zsh
exec zsh
```

### 5. Flatpak apps (post-boot manual; not declarative yet)

```sh
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Steam is native via programs.steam — don't double-install.
flatpak install -y flathub \
  md.obsidian.Obsidian \
  com.discordapp.Discord \
  com.google.Chrome \
  org.telegram.desktop \
  com.spotify.Client \
  com.slack.Slack \
  org.signal.Signal

flatpak list
```

### 6. CLIs not in nixpkgs

`nodejs_22` is provided by `home/dev-tools.nix`, so npm globals install OK.

```sh
npm install -g @openai/codex
npm install -g @google/gemini-cli@latest
command -v claude || npm install -g @anthropic-ai/claude-code
codex --version && gemini --version && claude --version

# OpenCode (separate installer)
curl -fsSL https://opencode.ai/install | bash
opencode --version

# SF Compute CLI
SF_VERSION=$(curl -s https://api.github.com/repos/sfcompute/cli/releases/latest | jq -r .tag_name)
curl -sL "https://github.com/sfcompute/cli/releases/download/${SF_VERSION}/sf-linux-amd64.zip" -o /tmp/sf.zip
unzip -o /tmp/sf.zip -d ~/.local/bin/
chmod +x ~/.local/bin/sf
sf --version
```

### 7. Google Sans + Google Sans Mono fonts (manual until overlay lands)

```sh
mkdir -p ~/.local/share/fonts/google-sans-mono ~/.local/share/fonts/google-sans
git clone https://github.com/mehant-kr/Google-Sans-Mono /tmp/gsm
cp /tmp/gsm/fonts/ttf/*.ttf ~/.local/share/fonts/google-sans-mono/
git clone https://github.com/nicholasgasior/gfonts /tmp/gfonts
cp /tmp/gfonts/google-sans/*.ttf ~/.local/share/fonts/google-sans/
fc-cache -fv
fc-match "Google Sans Mono"   # should resolve, not fall back
```

TODO: package as derivations in `nix/overlays/default.nix` so this becomes declarative.

### 8. Rollback strategy

```sh
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nixos-rebuild switch --rollback                                 # to previous
sudo /nix/var/nix/profiles/system-N-link/bin/switch-to-configuration switch  # to specific N
```

If the system won't boot: pick an older generation from the systemd-boot menu.

### 9. GPU smoke tests

Re-run after every physical swap and after every `just nixos-update`.

```sh
just ml-check
# Runs:
#   gpu-check    → nvidia-smi name/driver/VRAM/compute-cap
#   torch-check  → PyTorch sees the GPU, reports compute capability
#   jax-check    → JAX device list

# Manual extra (heavy):
nix develop .#ml -c uv run --with 'torch>=2.7' python -c "
import torch
x = torch.randn(8192, 8192, device='cuda')
y = x @ x.T
torch.cuda.synchronize()
print('OK', y.shape, y.device)
"
```

### 10. Tailscale rejoin

```sh
sudo tailscale up --ssh --accept-routes
# Browser auth. Confirm at https://login.tailscale.com/admin/machines
tailscale status
```

### 11. Claude Code RC services (Manifold only — 4 systemd user units)

```sh
systemctl --user list-units 'claude-rc-*' --no-pager
# Expected on Manifold:
#   claude-rc-manifold.service
#   claude-rc-projects.service
#   claude-rc-freectrl.service
#   claude-rc-rsde.service
# All active.

# Tail logs if any are failing:
journalctl --user -u claude-rc-manifold -n 50 --no-pager
```

---

## Driver-pin policy

`nvidiaPackages.beta` tracks nixos-unstable. A casual `nix flake update` can pull a driver regression. After each stable milestone, lock the flake explicitly:

```sh
cd ~/.dotfiles
sudo nixos-rebuild test --flake .#$(hostname)   # verify before committing the lock
just ml-check                                    # GPU smoke tests pass
git add flake.lock
git commit -m "lock(nixos): $(hostname) known-good baseline"
git push
```

**Rule:** do NOT run `nix flake update` or `just nixos-update` before a training run unless you are prepared to roll back. Always `just ml-check` before AND after any flake update.

---

## GPU transplant choreography (Phase 10 + 11)

### Phase 10 — Manifold: 5090 → Pro 6000

1. Confirm Pro 6000 power-connector matches PSU.
2. `sudo systemctl poweroff`.
3. Physical swap: remove 5090 (keep it — Phase 11 needs it), install Pro 6000.
4. Power on. Niri comes up identically; same Blackwell driver branch.
5. `just gpu-check` — expect ~98304 MiB, sm_120.
6. `just ml-check`.
7. Edit `nix/vars/default.nix` Manifold description (drop "planned" qualifier).
8. `sudo nixos-rebuild switch --flake .#manifold`.
9. Lock flake.lock + commit + push.

### Phase 11 — Tensor: 3080 → 5090

Tensor is already on NixOS from Phase 6. Same `nvidia.nix` covers both Ampere and Blackwell, so this is a hardware swap with metadata bump.

1. `sudo systemctl poweroff`.
2. Physical swap: remove 3080, install 5090.
3. Power on. Niri comes up; Blackwell driver picks up the new card.
4. `just gpu-check` — expect ~32607 MiB, sm_120.
5. `just ml-check`.
6. Edit `nix/vars/default.nix` Tensor description (drop "planned" qualifier).
7. Edit `docs/compute/tensor.md` GPU section.
8. `sudo nixos-rebuild switch --flake .#tensor`.
9. Lock flake.lock + commit + push.

3080 disposition: retire / sell / spare — user's call. Update `docs/compute/tensor.md`.
