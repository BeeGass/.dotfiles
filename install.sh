#!/bin/bash

# Dotfiles Installation Script
# This script sets up the dotfiles on a new machine

echo "🚀 Dotfiles Installation Script"
echo "=============================="
echo ""

# Check if running from remote (one-liner install)
REMOTE_INSTALL=false
if [[ "$1" == "--remote" ]]; then
    REMOTE_INSTALL=true
    echo "Running remote installation..."
    
    # Clone the repository first
    if [ ! -d "$HOME/.dotfiles" ]; then
        echo "Cloning dotfiles repository..."
        git clone https://github.com/BeeGass/.dotfiles.git "$HOME/.dotfiles" || {
            echo "Failed to clone repository. Trying with git@github.com..."
            git clone git@github.com:BeeGass/.dotfiles.git "$HOME/.dotfiles" || {
                echo "Failed to clone repository. Please check your internet connection and GitHub access."
                exit 1
            }
        }
    fi
    
    # Change to the dotfiles directory
    cd "$HOME/.dotfiles" || exit 1
fi

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=macOS;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac
echo "Detected OS: ${OS_TYPE}"
echo ""

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    
    # If target exists and is not a symlink, back it up
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "  Backing up existing $target to $target.backup"
        mv "$target" "$target.backup"
    fi
    
    # Create symlink
    ln -sfn "$source" "$target"
    echo "  ✓ Linked $source → $target"
}

echo "1. Creating symlinks..."
echo ""

# ZSH configuration
create_symlink "$HOME/.dotfiles/zsh/zshrc" "$HOME/.zshrc"

# Git configuration
# Check if user has existing git config to preserve
if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
    echo "  ⚠️  Existing .gitconfig found. Backing up and merging settings..."
    cp "$HOME/.gitconfig" "$HOME/.dotfiles/git/gitconfig.local"
    echo "  Your existing git config has been saved to ~/.dotfiles/git/gitconfig.local"
    echo "  Please review and merge any missing settings manually"
fi
create_symlink "$HOME/.dotfiles/git/gitconfig" "$HOME/.gitconfig"

# Vim configuration
create_symlink "$HOME/.dotfiles/vim/vimrc" "$HOME/.vimrc"

# SSH configuration
mkdir -p "$HOME/.ssh"
create_symlink "$HOME/.dotfiles/ssh/config" "$HOME/.ssh/config"

echo ""
echo "2. Installing required tools..."
echo ""

if [[ "$OS_TYPE" == "macOS" ]]; then
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "  Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    echo "  Installing tools via Homebrew..."
    brew install fzf eza bat ripgrep git-delta
    brew install jandedobbeleer/oh-my-posh/oh-my-posh
    brew install zsh-syntax-highlighting zsh-autosuggestions
    
    # Install FZF key bindings
    $(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
    
elif [[ "$OS_TYPE" == "Linux" ]]; then
    echo "  On Linux, please install the following packages using your package manager:"
    echo ""
    echo "  For Ubuntu/Debian:"
    echo "    sudo apt update"
    echo "    sudo apt install fzf eza bat ripgrep git-delta"
    echo "    sudo apt install zsh-syntax-highlighting zsh-autosuggestions"
    echo ""
    echo "  For Arch:"
    echo "    sudo pacman -S fzf eza bat ripgrep git-delta"
    echo "    sudo pacman -S zsh-syntax-highlighting zsh-autosuggestions"
    echo ""
    echo "  For Oh-My-Posh on Linux:"
    echo "    curl -s https://ohmyposh.dev/install.sh | bash -s"
fi

echo ""
echo "3. Setting up Git..."
echo ""

# Check if git user is configured
if ! git config --global user.name > /dev/null 2>&1; then
    read -p "  Enter your Git username: " git_username
    git config --global user.name "$git_username"
fi

if ! git config --global user.email > /dev/null 2>&1; then
    read -p "  Enter your Git email: " git_email
    git config --global user.email "$git_email"
fi

echo ""
echo "4. Font Installation"
echo ""
echo "  To install Google Sans Mono fonts:"
echo "    git clone git@github.com:hprobotic/Google-Sans-Font.git"
echo "    git clone git@github.com:mehant-kr/Google-Sans-Mono.git"
echo ""
if [[ "$OS_TYPE" == "macOS" ]]; then
    echo "  On macOS: Copy .ttf files to ~/Library/Fonts/"
else
    echo "  On Linux: Copy .ttf files to ~/.local/share/fonts/ and run fc-cache -f -v"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Configure your terminal to use Google Sans Mono font"
echo "  3. For iTerm2: Set a Nerd Font as the non-ASCII font for icons"
echo ""
echo "Useful commands:"
echo "  edit-omp     - Edit oh-my-posh theme"
echo "  reload-omp   - Reload oh-my-posh configuration"
echo "  cd ~pm       - Go to ~/Documents/Coding/PM"
echo "  cd ~ludo     - Go to ~/Documents/Coding/Ludo"
echo ""