#!/bin/bash

set -e

echo "=========================================="
echo "02 - Dotfiles Setup"
echo "=========================================="

# Install dotfiles
echo "Setting up dotfiles..."
cd ~
git clone https://github.com/matthewmyrick/dotfiles.git
cd dotfiles
chmod +x install.sh && ./install.sh
cd ~

echo "Dotfiles setup complete!"