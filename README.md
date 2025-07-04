# Dotfiles

Personal dotfiles configuration for macOS and Linux, featuring oh-my-posh, enhanced shell experience, and modern CLI tools.

## Features

- 🚀 **Oh-My-Posh** - Beautiful, customizable prompt based on powerlevel10k_modern
- 🔧 **Modular ZSH Configuration** - Organized into logical files for easy maintenance
- 🛠️ **Modern CLI Tools** - Integration with fzf, eza, bat, ripgrep, and git-delta
- 🐍 **UV Python Manager** - Fast Python package and project management
- 🔐 **GPG/YubiKey Integration** - Secure key management and SSH authentication
- 📁 **Smart Directory Navigation** - Bookmarks and enhanced completion
- 🎨 **Google Sans Mono** - Clean typography with Nerd Font fallback for icons
- 📜 **Custom Scripts** - Utility scripts automatically installed to ~/.local/bin
- 💻 **WezTerm** - GPU-accelerated terminal with custom configuration
- 🖥️ **Tmux** - Terminal multiplexer with vim-style keybindings and mouse support

## Quick Install

### One-liner Installation

Using curl:
```bash
curl -sSL https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install.sh | bash -s -- --remote
```

Using wget:
```bash
wget -qO- https://raw.githubusercontent.com/BeeGass/.dotfiles/main/install.sh | bash -s -- --remote
```

### Traditional Installation

```bash
git clone git@github.com:BeeGass/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## Manual Installation

### Prerequisites

- ZSH shell
- Git
- Terminal with 24-bit color support (iTerm2, Alacritty, etc.)

### macOS

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install fzf eza bat ripgrep git-delta wezterm tmux
brew install jandedobbeleer/oh-my-posh/oh-my-posh
brew install zsh-syntax-highlighting zsh-autosuggestions

# Clone dotfiles
git clone https://github.com/BeeGass/dotfiles.git ~/.dotfiles

# Create symlinks
ln -sfn ~/.dotfiles/zsh/zshrc ~/.zshrc
ln -sfn ~/.dotfiles/git/gitconfig ~/.gitconfig

# Install fonts
git clone git@github.com:hprobotic/Google-Sans-Font.git
git clone git@github.com:mehant-kr/Google-Sans-Mono.git
# Copy all .ttf files to the user fonts directory
cp Google-Sans-Font/*.ttf ~/Library/Fonts/
cp Google-Sans-Mono/*.ttf ~/Library/Fonts/
```

### Linux (Ubuntu/Debian)

```bash
# Install most tools
sudo apt update
sudo apt install -y fzf bat ripgrep zsh-syntax-highlighting zsh-autosuggestions tmux

# Install eza (requires adding repository)
sudo apt install -y gpg
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo apt update && sudo apt install -y eza

# Install git-delta
wget https://github.com/dandavison/delta/releases/latest/download/git-delta-musl_*_amd64.deb
sudo dpkg -i git-delta-musl_*_amd64.deb

# Install oh-my-posh
curl -s https://ohmyposh.dev/install.sh | bash -s

# Install WezTerm
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo apt update && sudo apt install -y wezterm

# Clone and setup
git clone https://github.com/BeeGass/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh

# Install fonts
git clone git@github.com:hprobotic/Google-Sans-Font.git
git clone git@github.com:mehant-kr/Google-Sans-Mono.git
# Create fonts directory if it doesn't exist
mkdir -p ~/.local/share/fonts
# Copy all .ttf files to the user fonts directory
cp Google-Sans-Font/*.ttf ~/.local/share/fonts/
cp Google-Sans-Mono/*.ttf ~/.local/share/fonts/
# Update font cache
fc-cache -f -v
```

### NixOS

Add to your `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  fzf
  eza
  bat
  ripgrep
  delta
  oh-my-posh
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-history-substring-search
  tmux
];
```

Then:
```bash
sudo nixos-rebuild switch
git clone https://github.com/BeeGass/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
```

## Directory Structure

```
.dotfiles/
├── zsh/                    # ZSH configuration
│   ├── zshrc              # Main entry point (symlinked to ~/.zshrc)
│   ├── 00-init.zsh        # Initial setup and core settings
│   ├── 10-oh-my-posh.zsh  # Prompt configuration
│   ├── 20-environment.zsh # Environment variables and paths
│   ├── 30-plugins.zsh     # ZSH plugin loading
│   ├── 40-aliases.zsh     # Shell aliases
│   ├── 50-functions.zsh   # Custom functions
│   ├── 60-completions.zsh # Completion settings
│   ├── 70-keybindings.zsh # Key bindings
│   ├── 80-tools.zsh       # External tool integration
│   └── 90-local.zsh       # Local overrides (git ignored)
├── oh-my-posh/            # Oh-My-Posh themes
│   ├── config.json        # Custom theme configuration
│   ├── setup.sh           # Legacy setup script
│   └── README.md          # Theme documentation
├── git/                   # Git configuration
│   ├── gitconfig          # Global git config (symlinked to ~/.gitconfig)
│   └── gitconfig.local    # Local overrides (git ignored)
├── vim/                   # Vim configuration
│   └── vimrc              # Vim settings (symlinked to ~/.vimrc)
├── tmux/                  # Tmux configuration
│   ├── tmux.conf          # Tmux settings (symlinked to ~/.tmux.conf)
│   └── README.md          # Comprehensive tmux documentation
├── wezterm/               # WezTerm terminal configuration
│   └── wezterm.lua        # WezTerm config (symlinked to ~/.config/wezterm/wezterm.lua)
├── ssh/                   # SSH configuration
│   ├── config             # SSH client config (symlinked to ~/.ssh/config)
│   └── .gitignore         # Ensures private keys are never committed
├── scripts/               # Utility scripts (symlinked to ~/.local/bin)
├── install.sh            # Installation script
├── refresh.sh            # Configuration verification script
├── README.md             # This file
└── .gitignore            # Repository ignore rules
```

## Configuration

### Terminal Font Setup

#### iTerm2
1. Open iTerm2 Preferences (`⌘,`)
2. Go to **Profiles → Text**
3. Set **Font**: Google Sans Mono (13-14pt)
4. Enable **Use a different font for non-ASCII text**
5. Set **Non-ASCII Font**: Any Nerd Font (for icons)

#### WezTerm
WezTerm is pre-configured with:
- **Font**: Google Sans Mono with Nerd Font fallback
- **Color Scheme**: Catppuccin Mocha
- **Transparency**: 90% window opacity
- **Key Bindings**: tmux-style with `Ctrl+A` as leader
- **GPU Acceleration**: Enabled for smooth performance

Key shortcuts:
- `Ctrl+A` then `|` = split horizontally
- `Ctrl+A` then `-` = split vertically
- `Ctrl+A` then `h/j/k/l` = navigate panes
- `Ctrl+A` then `c` = new tab
- `Ctrl+A` then `r` = reload config

### Tmux

Tmux is configured with vim-style keybindings and full mouse support. The prefix key is `Ctrl+a`.

Quick reference:
- `tmux` = start new session
- `tmux attach` = attach to existing session
- `Ctrl+a c` = new window
- `Ctrl+a |` = split vertically
- `Ctrl+a -` = split horizontally
- `Ctrl+a h/j/k/l` = navigate panes
- `Ctrl+a d` = detach from session

See the [full tmux documentation](tmux/README.md) for complete keybinding reference.

### Directory Bookmarks

Quick navigation shortcuts are pre-configured:

- `cd ~pm` → `~/Documents/Coding/PM`
- `cd ~ludo` → `~/Documents/Coding/Ludo`
- `cd ~dots` → `~/.dotfiles`
- `cd ~projects` → `~/Projects`
- `cd ~downloads` → `~/Downloads`
- `cd ~docs` → `~/Documents`

### Custom Commands

#### Utility Scripts
- `repo_to_text` - Convert repository contents to text format
- All scripts in `~/.dotfiles/scripts/` are automatically symlinked to `~/.local/bin/` and made executable

#### Oh-My-Posh
- `edit-omp` - Edit the oh-my-posh theme
- `reload-omp` - Reload configuration
- `switch-theme <name>` - Switch to a different theme

#### Python/UV
- `uvnew <project> [version]` - Create new Python project
- `uvsetup` - Install dependencies and activate venv
- `uvupgrade` - Sync all extras and upgrade dependencies
- `mkuv` - Create virtual environment
- `activateuv` - Activate virtual environment

#### Git Helpers
- `allbranches` - Track all remote branches locally
- `config` - Manage dotfiles with git bare repository

#### GPG/Security
- `keyconfirm` - Set up GPG agent for SSH
- `gpgmsg <recipient>` - Sign and encrypt message
- `yubioath` - List YubiKey OATH accounts

## Customization

### Adding Local Overrides

Create `~/.dotfiles/zsh/90-local.zsh` for machine-specific settings that won't be committed:

```bash
# Example: Company-specific aliases
alias work="cd ~/Company/projects"

# Example: Local environment variables
export COMPANY_API_KEY="..."
```

### Modifying the Theme

Edit `~/.dotfiles/oh-my-posh/config.json` to customize your prompt. The theme is based on powerlevel10k_modern with enhancements.

### Adding New Aliases/Functions

1. Add aliases to `~/.dotfiles/zsh/40-aliases.zsh`
2. Add functions to `~/.dotfiles/zsh/50-functions.zsh`
3. Reload with `source ~/.zshrc`

## Maintenance

### Verifying Installation

Run the refresh script to check if everything is properly configured:

```bash
~/.dotfiles/refresh.sh
```

This script will verify:
- All symlinks are correctly set up
- Required tools are installed
- PATH configuration is correct
- Git is properly configured
- ZSH plugins are available
- Fonts are installed
- Oh-My-Posh theme is valid

The script uses color-coded output:
- ✓ Green: Component is properly configured
- ⚠ Yellow: Optional component missing (warning)
- ✗ Red: Required component missing (failure)

## Troubleshooting

### Icons not displaying correctly
- Ensure you've set a Nerd Font as the non-ASCII font in your terminal
- Try "Symbols Nerd Font Mono" or "MesloLGS NF"

### Command not found errors
- Run the install script: `~/.dotfiles/install.sh`
- Ensure Homebrew is in your PATH (macOS)
- Check that all tools are installed

### Performance issues
- Oh-my-posh is generally fast, but you can disable git status for large repos
- Consider using the transient prompt feature: `enable-transient-prompt`

## Security Notes

- The gitconfig template excludes tokens - use git credential helpers
- GPG signing is enabled by default
- Local/private configurations are git-ignored

## License

These dotfiles are available under the MIT License. Feel free to fork and customize!

## Acknowledgments

- [Oh-My-Posh](https://ohmyposh.dev/) for the excellent prompt system
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) for theme inspiration
- All the amazing open source tool authors