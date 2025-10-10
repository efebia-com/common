# Common Server Configuration Files

Shared configuration files and utilities for server provisioning and setup.

## Ghostty Terminfo

Terminfo database entry for [Ghostty terminal emulator](https://ghostty.org/) to enable full terminal capabilities on remote servers.

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/common/main/install.sh | bash
```

Or manually:

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/common/main/xterm-ghostty.terminfo
tic -x xterm-ghostty.terminfo
```

### What This Fixes

Without this terminfo, when connecting to remote servers via Ghostty you may see:
- `Error opening terminal: xterm-ghostty` when running htop, vim, etc.
- Broken colors or UI in terminal applications

This terminfo file enables:
- Full color support (256 colors)
- Proper terminal capabilities
- htop, vim, tmux, and other ncurses applications work correctly

### Files

- `xterm-ghostty.terminfo` - Terminfo database entry for Ghostty
- `install.sh` - Automated installation script

### About

Exported from Ghostty 1.0.1 on Ubuntu 24.04.
