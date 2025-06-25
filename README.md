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
brew install fzf eza bat ripgrep git-delta
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
# Copy .ttf files to ~/Library/Fonts/
```

### Linux

```bash
# Install tools (Ubuntu/Debian)
sudo apt update
sudo apt install fzf eza bat ripgrep git-delta zsh-syntax-highlighting zsh-autosuggestions

# Install oh-my-posh
curl -s https://ohmyposh.dev/install.sh | bash -s

# Clone and setup (same as macOS)
git clone https://github.com/BeeGass/dotfiles.git ~/.dotfiles
ln -sfn ~/.dotfiles/zsh/zshrc ~/.zshrc
ln -sfn ~/.dotfiles/git/gitconfig ~/.gitconfig

# Install fonts to ~/.local/share/fonts/ and run fc-cache -f -v
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
├── ssh/                   # SSH configuration
│   ├── config             # SSH client config (symlinked to ~/.ssh/config)
│   └── .gitignore         # Ensures private keys are never committed
├── scripts/               # Utility scripts
├── install.sh            # Installation script
├── README.md             # This file
└── .gitignore            # Repository ignore rules
```

## Configuration

### Terminal Font Setup (iTerm2)

1. Open iTerm2 Preferences (`⌘,`)
2. Go to **Profiles → Text**
3. Set **Font**: Google Sans Mono (13-14pt)
4. Enable **Use a different font for non-ASCII text**
5. Set **Non-ASCII Font**: Any Nerd Font (for icons)

### Directory Bookmarks

Quick navigation shortcuts are pre-configured:

- `cd ~pm` → `~/Documents/Coding/PM`
- `cd ~ludo` → `~/Documents/Coding/Ludo`
- `cd ~dots` → `~/.dotfiles`
- `cd ~projects` → `~/Projects`
- `cd ~downloads` → `~/Downloads`
- `cd ~docs` → `~/Documents`

### Custom Commands

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