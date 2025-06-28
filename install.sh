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

# WezTerm configuration
mkdir -p "$HOME/.config/wezterm"
create_symlink "$HOME/.dotfiles/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"

# SSH configuration
mkdir -p "$HOME/.ssh"
create_symlink "$HOME/.dotfiles/ssh/config" "$HOME/.ssh/config"

# Scripts - symlink to ~/.local/bin
echo ""
echo "Setting up scripts..."
mkdir -p "$HOME/.local/bin"

# Symlink all scripts in the scripts directory
if [ -d "$HOME/.dotfiles/scripts" ]; then
    for script in "$HOME/.dotfiles/scripts"/*; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")
            create_symlink "$script" "$HOME/.local/bin/$script_name"
            chmod +x "$script"
            echo "  Made $script_name executable"
        fi
    done
fi

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "  ⚠️  ~/.local/bin is not in your PATH. It will be added when you source ~/.zshrc"
fi

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
    brew install fzf eza bat ripgrep git-delta wezterm
    brew install jandedobbeleer/oh-my-posh/oh-my-posh
    brew install zsh-syntax-highlighting zsh-autosuggestions
    
    # Install FZF key bindings
    $(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish
    
elif [[ "$OS_TYPE" == "Linux" ]]; then
    echo "  On Linux, please install the following packages:"
    echo ""
    
    # Check if running on NixOS
    if [ -f /etc/NIXOS ]; then
        echo "  For NixOS:"
        echo "    Add these packages to your configuration.nix:"
        echo "      environment.systemPackages = with pkgs; ["
        echo "        fzf"
        echo "        eza"
        echo "        bat"
        echo "        ripgrep"
        echo "        delta"
        echo "        oh-my-posh"
        echo "        zsh-syntax-highlighting"
        echo "        zsh-autosuggestions"
        echo "        zsh-history-substring-search"
        echo "        wezterm"
        echo "      ];"
        echo ""
        echo "    Then run: sudo nixos-rebuild switch"
    else
        # Ubuntu/Debian instructions
        echo "  For Ubuntu/Debian:"
        echo "    sudo apt update"
        echo "    sudo apt install -y fzf bat ripgrep zsh-syntax-highlighting zsh-autosuggestions"
        echo "    # Optional: For history substring search"
        echo "    sudo apt install -y zsh-history-substring-search"
        echo ""
        echo "    # Install eza (not in standard repos)"
        echo "    sudo apt install -y gpg"
        echo "    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg"
        echo "    echo \"deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main\" | sudo tee /etc/apt/sources.list.d/gierens.list"
        echo "    sudo apt update"
        echo "    sudo apt install -y eza"
        echo ""
        echo "    # Install git-delta"
        echo "    wget https://github.com/dandavison/delta/releases/latest/download/git-delta-musl_*_amd64.deb"
        echo "    sudo dpkg -i git-delta-musl_*_amd64.deb"
        echo ""
        echo "    # Install Oh-My-Posh"
        echo "    curl -s https://ohmyposh.dev/install.sh | bash -s"
        echo ""
        echo "    # Install WezTerm"
        echo "    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg"
        echo "    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list"
        echo "    sudo apt update"
        echo "    sudo apt install -y wezterm"
    fi
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
    echo "  On macOS:"
    echo "    # Copy all .ttf files to the user fonts directory"
    echo "    cp Google-Sans-Font/*.ttf ~/Library/Fonts/"
    echo "    cp Google-Sans-Mono/*.ttf ~/Library/Fonts/"
else
    echo "  On Linux:"
    echo "    # Create fonts directory if it doesn't exist"
    echo "    mkdir -p ~/.local/share/fonts"
    echo "    # Copy all .ttf files to the user fonts directory"
    echo "    cp Google-Sans-Font/*.ttf ~/.local/share/fonts/"
    echo "    cp Google-Sans-Mono/*.ttf ~/.local/share/fonts/"
    echo "    # Update font cache"
    echo "    fc-cache -f -v"
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