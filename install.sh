#!/bin/bash
set -e

echo "Installing Ghostty terminfo..."

# Download terminfo
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/ghostty-terminfo/main/xterm-ghostty.terminfo -o /tmp/xterm-ghostty.terminfo

# Install terminfo
tic -x /tmp/xterm-ghostty.terminfo

# Clean up
rm /tmp/xterm-ghostty.terminfo

echo "✓ Ghostty terminfo installed successfully!"
echo "Terminal applications like htop should now work correctly."
