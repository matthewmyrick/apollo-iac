#!/bin/bash

set -e

echo "=========================================="
echo "01 - System Packages Setup"
echo "=========================================="

# Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo "Installing essential packages..."
sudo apt install -y curl wget openssh-server ufw fail2ban git zsh eza fd-find fzf yazi zsh-autosuggestions zsh-syntax-highlighting bat

echo "System packages installation complete!"