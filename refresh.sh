#!/bin/bash

# Dotfiles Refresh/Sanity Check Script
# This script verifies that all dotfiles components are properly installed and configured

echo "🔍 Dotfiles Configuration Check"
echo "=============================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters for summary
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Check function
check() {
    local description="$1"
    local condition="$2"
    
    printf "%-50s" "$description"
    
    if eval "$condition"; then
        echo -e "${GREEN}✓ OK${NC}"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Warning function
warn_check() {
    local description="$1"
    local condition="$2"
    local fix_msg="$3"
    
    printf "%-50s" "$description"
    
    if eval "$condition"; then
        echo -e "${GREEN}✓ OK${NC}"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        echo "  └─ Fix: $fix_msg"
        ((WARN_COUNT++))
        return 1
    fi
}

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=macOS;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac

echo "1. Checking Symlinks"
echo "-------------------"

# Check dotfile symlinks
check "~/.zshrc → ~/.dotfiles/zsh/zshrc" \
    "[ -L '$HOME/.zshrc' ] && [ -e '$HOME/.zshrc' ] && [ -e '$HOME/.dotfiles/zsh/zshrc' ]"

check "~/.gitconfig → ~/.dotfiles/git/gitconfig" \
    "[ -L '$HOME/.gitconfig' ] && [ -e '$HOME/.gitconfig' ] && [ -e '$HOME/.dotfiles/git/gitconfig' ]"

check "~/.vimrc → ~/.dotfiles/vim/vimrc" \
    "[ -L '$HOME/.vimrc' ] && [ -e '$HOME/.vimrc' ] && [ -e '$HOME/.dotfiles/vim/vimrc' ]"

check "~/.ssh/config → ~/.dotfiles/ssh/config" \
    "[ -L '$HOME/.ssh/config' ] && [ -e '$HOME/.ssh/config' ] && [ -e '$HOME/.dotfiles/ssh/config' ]"

# Check script symlinks
echo ""
echo "Checking script symlinks..."
if [ -d "$HOME/.dotfiles/scripts" ]; then
    for script in "$HOME/.dotfiles/scripts"/*; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")
            check "  ~/.local/bin/$script_name" \
                "[ -L '$HOME/.local/bin/$script_name' ] && [ -e '$HOME/.local/bin/$script_name' ] && [ -x '$script' ]"
        fi
    done
else
    echo "  No scripts directory found"
fi

echo ""
echo "2. Checking Required Tools"
echo "-------------------------"

# Core tools
check "ZSH installed" "command -v zsh &> /dev/null"
check "Git installed" "command -v git &> /dev/null"
check "Oh-My-Posh installed" "command -v oh-my-posh &> /dev/null"

# CLI tools
check "fzf installed" "command -v fzf &> /dev/null"
check "eza installed" "command -v eza &> /dev/null"
check "bat installed" "command -v bat &> /dev/null"
check "ripgrep installed" "command -v rg &> /dev/null"
check "git-delta installed" "command -v delta &> /dev/null"

# Optional tools
warn_check "uv (Python) installed" "command -v uv &> /dev/null" \
    "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"

echo ""
echo "3. Checking PATH Configuration"
echo "-----------------------------"

check "~/.local/bin in PATH" "[[ ':$PATH:' == *':$HOME/.local/bin:'* ]]"

if [[ "$OS_TYPE" == "macOS" ]]; then
    warn_check "Homebrew in PATH" "command -v brew &> /dev/null" \
        "Install Homebrew: /bin/bash -c '\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'"
fi

echo ""
echo "4. Checking Git Configuration"
echo "----------------------------"

check "Git user.name configured" "git config --global user.name &> /dev/null"
check "Git user.email configured" "git config --global user.email &> /dev/null"

# Check if commit signing is enabled
if git config --global commit.gpgsign &> /dev/null && [ "$(git config --global commit.gpgsign)" = "true" ]; then
    warn_check "GPG signing key configured" "git config --global user.signingkey &> /dev/null" \
        "Set with: git config --global user.signingkey <your-key-id>"
fi

echo ""
echo "5. Checking ZSH Plugin Dependencies"
echo "----------------------------------"

if [[ "$OS_TYPE" == "macOS" ]]; then
    check "zsh-syntax-highlighting" "[ -d '/opt/homebrew/share/zsh-syntax-highlighting' ] || [ -d '/usr/local/share/zsh-syntax-highlighting' ]"
    check "zsh-autosuggestions" "[ -d '/opt/homebrew/share/zsh-autosuggestions' ] || [ -d '/usr/local/share/zsh-autosuggestions' ]"
else
    # Linux paths
    check "zsh-syntax-highlighting" \
        "[ -d '/usr/share/zsh-syntax-highlighting' ] || [ -d '/usr/share/zsh/plugins/zsh-syntax-highlighting' ] || [ -f '/etc/zsh_command_not_found' ]"
    check "zsh-autosuggestions" \
        "[ -d '/usr/share/zsh-autosuggestions' ] || [ -d '/usr/share/zsh/plugins/zsh-autosuggestions' ]"
fi

echo ""
echo "6. Checking Font Installation"
echo "----------------------------"

if [[ "$OS_TYPE" == "macOS" ]]; then
    warn_check "Google Sans Mono installed" \
        "ls ~/Library/Fonts/GoogleSans*Mono*.ttf &> /dev/null || ls /Library/Fonts/GoogleSans*Mono*.ttf &> /dev/null" \
        "See font installation instructions in README.md"
else
    warn_check "Google Sans Mono installed" \
        "fc-list | grep -i 'google.*sans.*mono' &> /dev/null" \
        "Copy fonts to ~/.local/share/fonts/ and run fc-cache -f -v"
fi

echo ""
echo "7. Checking Directory Structure"
echo "------------------------------"

check "~/.local/bin exists" "[ -d '$HOME/.local/bin' ]"
check "~/.dotfiles exists" "[ -d '$HOME/.dotfiles' ]"
check "SSH directory exists" "[ -d '$HOME/.ssh' ]"

# Check for local override file
warn_check "Local ZSH overrides file" "[ -f '$HOME/.dotfiles/zsh/90-local.zsh' ]" \
    "Create ~/.dotfiles/zsh/90-local.zsh for machine-specific settings"

echo ""
echo "8. Checking Oh-My-Posh Theme"
echo "---------------------------"

check "Oh-My-Posh config exists" "[ -f '$HOME/.dotfiles/oh-my-posh/config.json' ]"

# Verify theme can be loaded
if command -v oh-my-posh &> /dev/null && [ -f "$HOME/.dotfiles/oh-my-posh/config.json" ]; then
    if oh-my-posh config validate --config "$HOME/.dotfiles/oh-my-posh/config.json" &> /dev/null; then
        echo -e "  Theme validation: ${GREEN}✓ Valid${NC}"
        ((PASS_COUNT++))
    else
        echo -e "  Theme validation: ${RED}✗ Invalid${NC}"
        ((FAIL_COUNT++))
    fi
fi

echo ""
echo "=============================="
echo "Summary"
echo "=============================="
echo -e "Passed:   ${GREEN}$PASS_COUNT${NC}"
echo -e "Warnings: ${YELLOW}$WARN_COUNT${NC}"
echo -e "Failed:   ${RED}$FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
    echo -e "${GREEN}✨ Everything looks good!${NC}"
    exit 0
elif [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Some optional components are missing${NC}"
    echo "   Run ./install.sh to set up missing components"
    exit 0
else
    echo -e "${RED}❌ Some required components are missing or misconfigured${NC}"
    echo "   Run ./install.sh to fix the issues"
    exit 1
fi