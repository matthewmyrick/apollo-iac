#!/bin/bash

set -e

echo "=========================================="
echo "05 - Tailscale Setup"
echo "=========================================="

# Install Tailscale with SSH support
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "Enabling Tailscale SSH server..."
echo "Note: You'll need to authenticate with Tailscale after running 'sudo tailscale up --ssh'"

echo "Tailscale installation complete!"
echo "To connect to Tailscale with SSH enabled, run: sudo tailscale up --ssh"
echo "After authentication, you can SSH from any tailnet device without managing keys!"