# NixOS Post-Install Runbook

Post-boot setup that the install plan (`docs/nixos/manifold-install-plan.md`) doesn't cover: YubiKey bootstrap, pass sync, machine-local zsh overrides, Flatpak apps, CLIs not in nixpkgs, fonts, and verification.

---

## 1. Verify NVIDIA driver loaded

```sh
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv
# Expected on Manifold: NVIDIA RTX Pro 6000, driver 580.x, ~98304 MiB, 12.0 (Blackwell sm_120)
```

## 2. YubiKey GPG bootstrap (one-time, interactive)

```sh
~/.local/bin/setup_gpg_ssh.sh --regen
# Prompts for YubiKey touch. Imports pubkey from GitHub, links gpg-agent SSH socket.

gpg --card-status        # shows YubiKey serial + key info
ssh-add -L               # shows YubiKey-backed SSH key
ssh -T git@github.com    # should authenticate
```

## 3. Pass store init + sync from Jacobian

```sh
pass init 0xACC3640C138D96A2

# Clone the pass-store git remote from Jacobian.
ssh Jacobian "cat ~/.password-store/.git/config"   # confirm remote
cd ~ && git clone ubuntu@Jacobian:/home/ubuntu/.password-store .password-store

# Or use justfile shortcuts:
just secrets-init
just secrets-pull
load-secrets    # confirms env vars source successfully
```

## 4. Seed `~/.dotfiles/zsh/90-local.zsh` (NON-SECRET paths only)

**Policy:** `90-local.zsh` is gitignored but lives inside the dotfiles repo. **API keys, tokens, and other secrets MUST NOT live here.** Secrets go through `pass` + `load-secrets`.

```sh
cat > ~/.dotfiles/zsh/90-local.zsh <<'EOF'
# Machine-local zsh overrides. NOT COMMITTED (per .gitignore).
# Sourced by zsh/zshrc near the end. Non-secret paths only.
#
# SECRETS POLICY: API keys and tokens are loaded via `load-secrets` from the
# pass store. Run `load-secrets` in any shell that needs them.

# Hugging Face cache + ML roots (also system sessionVariables; redundant for
# tools that read shell init like some IDE terminals).
export HF_HOME="/data/hf-cache"
export HF_HUB_CACHE="/data/hf-cache/hub"
export TRANSFORMERS_CACHE="/data/hf-cache"
export DATASETS_ROOT="/data/datasets"
export MODELS_ROOT="/models"
export CHECKPOINTS_ROOT="/checkpoints"
export SCRATCH_ROOT="/work/scratch"

# OpenCode CLI (installed manually, not in nixpkgs)
export PATH="$HOME/.opencode/bin:$PATH"

# Local LLM endpoints (uncomment if running ollama/llama.cpp locally)
# export OLLAMA_HOST="http://localhost:11434"
EOF
chmod 644 ~/.dotfiles/zsh/90-local.zsh
exec zsh
```

## 5. Flatpak apps (post-boot manual; not declarative yet)

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

## 6. CLIs not in nixpkgs

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

## 7. Google Sans + Google Sans Mono fonts (manual until overlay lands)

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

## 8. GPU smoke tests

Re-run after every physical change and after every `just nixos-update`.

```sh
just ml-check
# Runs:
#   gpu-check    -> nvidia-smi name/driver/VRAM/compute-cap
#   torch-check  -> PyTorch sees the GPU, reports compute capability
#   jax-check    -> JAX device list

# Manual extra (heavy):
nix develop .#ml -c uv run --with 'torch>=2.7' python -c "
import torch
x = torch.randn(8192, 8192, device='cuda')
y = x @ x.T
torch.cuda.synchronize()
print('OK', y.shape, y.device)
"
```

## 9. Tailscale rejoin

```sh
sudo tailscale up --ssh --accept-routes
# Browser auth. Confirm at https://login.tailscale.com/admin/machines
tailscale status
```

## 10. Claude Code RC services (4 systemd user units)

```sh
systemctl --user list-units 'claude-rc-*' --no-pager
# Expected:
#   claude-rc-manifold.service
#   claude-rc-projects.service
#   claude-rc-freectrl.service
#   claude-rc-rsde.service
# All active.

journalctl --user -u claude-rc-manifold -n 50 --no-pager
```

## 11. Mount + drive verification

```sh
findmnt -t btrfs,xfs,vfat,ext4 | grep -v snap
df -h /data /srv/ml /models /checkpoints /work /games /rescue
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT
btrfs subvolume list /
cryptsetup status cryptroot
swapon --show
```

---

## Rollback strategy

```sh
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nixos-rebuild switch --rollback                                 # to previous
sudo /nix/var/nix/profiles/system-N-link/bin/switch-to-configuration switch  # to specific N
```

If the system won't boot: pick an older generation from the systemd-boot menu.

---

## Driver-pin policy

`nvidiaPackages.beta` tracks nixos-unstable. A casual `nix flake update` can pull a driver regression. After each stable milestone, lock the flake explicitly:

```sh
cd ~/.dotfiles
sudo nixos-rebuild test --flake .#manifold     # verify before committing the lock
just ml-check                                   # GPU smoke tests pass
git add flake.lock
git commit -m "lock(nixos): manifold known-good baseline"
git push
```

**Rule:** do NOT run `nix flake update` or `just nixos-update` before a training run unless you are prepared to roll back. Always `just ml-check` before AND after any flake update.
