# TMUX Configuration

This directory contains my personal tmux configuration optimized for productivity and ease of use.

## Table of Contents
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Key Concepts](#key-concepts)
- [Essential Commands](#essential-commands)
- [Complete Keybinding Reference](#complete-keybinding-reference)
- [Features](#features)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Quick Start

```bash
# Install tmux
sudo apt install tmux

# Start a new tmux session
tmux

# Start a named session
tmux new -s work

# List sessions
tmux ls

# Attach to a session
tmux attach -t work

# Detach from session
Ctrl+Space d
```

## Installation

The tmux configuration is deployed automatically by chezmoi:

```bash
# Apply dotfiles (includes tmux.conf)
just apply

# Or directly with chezmoi
chezmoi apply
```

The config is deployed to `~/.tmux.conf` from the chezmoi source at `home/dot_tmux.conf`.

## Key Concepts

### Sessions, Windows, and Panes

```
Session (workspace)
├── Window 1 (tab)
│   ├── Pane 1
│   └── Pane 2
├── Window 2 (tab)
│   └── Pane 1
└── Window 3 (tab)
    ├── Pane 1
    ├── Pane 2
    └── Pane 3
```

- **Session**: A collection of windows, like a workspace
- **Window**: Like a tab in your terminal (shown in status bar)
- **Pane**: A split within a window

### The Prefix Key

All tmux commands start with the **prefix key**: `Ctrl+Space`

To send a literal `Ctrl+Space` to applications, press `Ctrl+Space` twice.

> Note: Many tmux guides use `Ctrl+b` (the default) or `Ctrl+a`. This config uses `Ctrl+Space` instead.

## Essential Commands

### Session Management

| Command | Description |
|---------|-------------|
| `tmux new -s name` | Create new named session |
| `tmux ls` | List all sessions |
| `tmux attach -t name` | Attach to named session |
| `tmux kill-session -t name` | Kill named session |
| `Ctrl+Space d` | Detach from current session |
| `Ctrl+Space s` | List and switch sessions |
| `Ctrl+Space $` | Rename current session |
| `Ctrl+Space (` | Switch to previous session |
| `Ctrl+Space )` | Switch to next session |

### Window (Tab) Management

| Command | Description |
|---------|-------------|
| `Ctrl+Space c` | Create new window |
| `Ctrl+Space n` | Next window |
| `Ctrl+Space p` | Previous window |
| `Ctrl+Space l` | Last window (toggle) |
| `Ctrl+Space 0-9` | Switch to window 0-9 |
| `Ctrl+Space w` | List all windows |
| `Ctrl+Space ,` | Rename current window |
| `Ctrl+Space &` | Kill current window (with confirmation) |

### Pane Management

| Command | Description |
|---------|-------------|
| `Ctrl+Space |` | Split pane vertically |
| `Ctrl+Space -` | Split pane horizontally |
| `Ctrl+Space h/j/k/l` | Navigate panes (vim-style) |
| `Ctrl+Space H/J/K/L` | Resize panes (repeatable) |
| `Ctrl+Space x` | Kill current pane |
| `Ctrl+Space z` | Toggle pane zoom (fullscreen) |
| `Ctrl+Space Space` | Cycle through pane layouts |
| `Ctrl+Space {` | Move pane left |
| `Ctrl+Space }` | Move pane right |
| `Ctrl+Space q` | Show pane numbers |
| `Ctrl+Space o` | Cycle through panes |

### Copy Mode

| Command | Description |
|---------|-------------|
| `Ctrl+Space [` | Enter copy mode |
| `q` or `Escape` | Exit copy mode |
| `Space` or `v` | Start selection |
| `Enter` or `y` | Copy selection |
| `Ctrl+Space ]` | Paste from buffer |

**In copy mode (vim bindings):**
- `h/j/k/l` - Navigate
- `w/b` - Next/previous word
- `f/F` - Find character forward/backward
- `/` - Search forward
- `?` - Search backward
- `n/N` - Next/previous search result
- `gg/G` - Go to top/bottom
- `V` - Select line
- `v` - Visual selection
- `r` - Rectangle selection

### Mouse Controls

| Action | Result |
|--------|--------|
| Click pane | Select pane |
| Click window (status bar) | Select window |
| Drag pane border | Resize pane |
| Scroll | Scroll through pane history |
| Right-click | Paste from tmux buffer |
| Shift+click | Select text (bypasses tmux) |
| Drag in copy mode | Select text |

## Complete Keybinding Reference

### System Commands

| Binding | Action |
|---------|--------|
| `Ctrl+Space ?` | Show all key bindings |
| `Ctrl+Space :` | Enter command prompt |
| `Ctrl+Space r` | Reload configuration |
| `Ctrl+Space t` | Show time |

### Advanced Pane Commands

| Binding | Action |
|---------|--------|
| `Ctrl+Space !` | Break pane into new window |
| `Ctrl+Space m` | Mark pane |
| `Ctrl+Space M` | Clear marked pane |
| `Ctrl+Space >` | Swap with next pane |
| `Ctrl+Space <` | Swap with previous pane |

## Features

### Appearance
- **Minimal black theme** with transparency support
- **Status bar** shows windows and time
- **Active window** highlighted in gray
- **Clean borders** for easy pane identification

### Mouse Support
- Full mouse integration for clicking, scrolling, and resizing
- Right-click to paste
- Drag to select text in copy mode

### Vim Integration
- Vim-style navigation keys
- Vim mode in copy mode
- Seamless integration with vim/neovim

### Performance
- Optimized for fast key response
- Large scrollback buffer (10,000 lines)
- Efficient status updates

## Customization

### Changing the Color Scheme

Edit `~/.dotfiles/home/dot_tmux.conf` (then run `just apply`):

```bash
# Status bar colors
set -g status-style 'bg=black fg=white'

# Window colors
setw -g window-status-current-style 'fg=white bg=#333333 bold'
setw -g window-status-style 'fg=#888888 bg=#111111'

# Pane borders
set -g pane-border-style 'fg=#333333'
set -g pane-active-border-style 'fg=white'
```

### Adding to Status Bar

```bash
# Left side
set -g status-left '[#S] '

# Right side
set -g status-right '#[fg=yellow]#(uptime | cut -d "," -f 1) #[fg=white]%H:%M '
```

### Custom Key Bindings

Add new bindings to the config:

```bash
# Example: Split panes with v and s
bind v split-window -h
bind s split-window -v
```

## Troubleshooting

### Colors Look Wrong

```bash
# Add to your shell RC file
export TERM=screen-256color
```

### Mouse Not Working

Ensure you have tmux 2.1 or later:
```bash
tmux -V
```

### Can't Copy to System Clipboard

Install xclip:
```bash
sudo apt install xclip
```

### Prefix Key Conflicts

If `Ctrl+Space` conflicts with other programs, change the prefix in `~/.dotfiles/home/dot_tmux.conf`:
```bash
# Change to Ctrl+b (tmux default)
set -g prefix C-b
unbind C-Space
```

## Advanced Usage

### Scripting Sessions

Create a project startup script:

```bash
#!/bin/bash
# ~/scripts/dev-session.sh

tmux new-session -d -s dev
tmux send-keys -t dev 'cd ~/project' C-m
tmux split-window -h -t dev
tmux send-keys -t dev 'npm run dev' C-m
tmux split-window -v -t dev
tmux send-keys -t dev 'git status' C-m
tmux attach -t dev
```

### Synchronized Panes

Control multiple panes simultaneously:
```bash
# Toggle synchronization
Ctrl+Space :setw synchronize-panes
```

### Save/Restore Sessions

Using tmux-resurrect plugin (uncomment in config):
- `Ctrl+Space Ctrl+s` - Save session
- `Ctrl+Space Ctrl+r` - Restore session

### Remote Pair Programming

```bash
# Host
tmux new -s pair

# Guest (same machine)
tmux attach -t pair

# Over SSH
ssh user@host -t tmux attach -t pair
```

### Integration with Terminal

For best integration with WezTerm or other terminals:

1. Start tmux automatically:
   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   if [ -z "$TMUX" ]; then
       tmux attach -t default || tmux new -s default
   fi
   ```

2. Or use terminal launch command:
   ```bash
   wezterm start -- tmux new -s main
   ```

## Tips and Tricks

1. **Quick window switching**: Use `Ctrl+Space` followed by window number
2. **Zoom for focus**: `Ctrl+Space z` to zoom current pane
3. **Resize precisely**: Hold `Ctrl+Space` and press `H/J/K/L` multiple times
4. **Copy mode search**: In copy mode, use `/` to search
5. **Command history**: `Ctrl+Space :` then use up/down arrows
6. **Rename for organization**: Name your windows and sessions meaningfully
7. **Layout presets**: `Ctrl+Space Space` cycles through useful layouts

## Resources

- [Tmux Manual](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [Tmux Cheat Sheet](https://tmuxcheatsheet.com/)
- [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm)