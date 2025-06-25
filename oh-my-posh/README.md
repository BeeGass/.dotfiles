# Oh-My-Posh Configuration

This directory contains a custom oh-my-posh configuration that ports features from oh-my-zsh while adding modern enhancements.

## Files

- `config.json` - Main oh-my-posh theme configuration
- `setup.sh` - Automated setup script for transitioning from oh-my-zsh
- `README.md` - This documentation file

## Features

### Preserved from oh-my-zsh
- All custom aliases and functions
- GPG/SSH key management
- Python environment management (now using uv instead of pyenv/poetry)
- Git integration with detailed status
- Battery status display
- Vi-mode support
- Syntax highlighting and autosuggestions
- Command execution time tracking

### New Features
- Modern, customizable prompt theme
- Transient prompt support (minimal prompt for previous commands)
- Better performance than Powerlevel10k
- Cross-platform support (macOS and Linux)
- Google Sans/Google Sans Mono font support
- UV package manager integration

## Installation

1. Run the setup script:
   ```bash
   ~/.config/oh-my-posh/setup.sh
   ```

2. Install fonts:
   ```bash
   git clone git@github.com:hprobotic/Google-Sans-Font.git
   git clone git@github.com:mehant-kr/Google-Sans-Mono.git
   ```
   Then follow the platform-specific instructions in the setup output.

3. Activate the new configuration:
   ```bash
   mv ~/.zshrc.oh-my-posh ~/.zshrc
   source ~/.zshrc
   ```

## Theme Structure

The theme includes these segments:

### Left Prompt
1. **OS Icon** - Shows the operating system
2. **Username** - Current user
3. **Directory** - Current working directory with folder navigation
4. **Git Status** - Branch, commits, staged/unstaged changes
5. **Python** - Virtual environment and Python version
6. **Node.js** - Node version and package manager
7. **Rust** - Rust version (when in Rust projects)
8. **Julia** - Julia version (when in Julia projects)
9. **Battery** - Battery status with color coding
10. **Execution Time** - Shows duration of long-running commands

### Right Prompt
- **Time** - Current time in 24-hour format

### Prompt Symbol
- Green `❯` for successful commands
- Red `❯` for failed commands

## Color Palette

The theme uses a carefully selected color palette:
- Primary: `#3b78ff` (Blue)
- Secondary: `#61d6d6` (Cyan)
- Tertiary: `#f2b482` (Orange)
- Success: `#16c98d` (Green)
- Warning: `#ffc83f` (Yellow)
- Error: `#fa7783` (Red)

## Custom Commands

### Oh-My-Posh Commands
- `reload-omp` - Reload the oh-my-posh configuration
- `edit-omp` - Edit your theme configuration
- `switch-theme <name>` - Switch to a different oh-my-posh theme
- `enable-transient-prompt` - Toggle transient prompt mode

### UV Python Commands
- `uvnew <project> [version]` - Create a new Python project
- `uvsetup` - Install dependencies and activate virtual environment
- `uvupgrade` - Sync all extras and upgrade all dependencies
- `mkuv` - Create a new virtual environment
- `activateuv` - Activate the virtual environment

### Git Commands
- `allbranches` - Track all remote branches locally
- `config` - Manage dotfiles with git bare repository

### GPG/Security Commands
- `keyconfirm` - Set up GPG agent for SSH
- `gpgmsg <recipient>` - Sign and encrypt a message
- `yubioath` - List YubiKey OATH accounts

## Customization

To customize the theme:

1. Edit the configuration:
   ```bash
   edit-omp
   ```

2. Key areas to customize:
   - `palette` - Modify colors
   - `blocks` - Add/remove/reorder prompt segments
   - `segments.properties` - Adjust segment behavior

3. Reload after changes:
   ```bash
   reload-omp
   ```

## Font Configuration

For the best experience, use Google Sans Mono:

### macOS
1. Double-click `.ttf` files to install
2. In iTerm2: Preferences → Profiles → Text → Font
3. Select "Google Sans Mono" and your preferred size

### Linux
1. Copy fonts to `~/.local/share/fonts/`
2. Run `fc-cache -f -v`
3. Configure your terminal to use the font

## Troubleshooting

### Prompt not displaying correctly
- Ensure your terminal supports powerline fonts
- Check that oh-my-posh is installed: `which oh-my-posh`
- Verify the config path: `echo $OH_MY_POSH_CONFIG`

### Missing icons/glyphs
- Install a Nerd Font or use Google Sans Mono
- Ensure your terminal is configured to use the font

### Performance issues
- Oh-my-posh is generally faster than Powerlevel10k
- Disable git status for large repositories by modifying the git segment

### Reverting to oh-my-zsh
```bash
mv ~/.zshrc.oh-my-zsh.backup.<timestamp> ~/.zshrc
source ~/.zshrc
```

## Resources

- [Oh-My-Posh Documentation](https://ohmyposh.dev/docs/)
- [Oh-My-Posh Themes](https://ohmyposh.dev/docs/themes)
- [Google Sans Font](https://github.com/hprobotic/Google-Sans-Font)
- [Google Sans Mono](https://github.com/mehant-kr/Google-Sans-Mono)