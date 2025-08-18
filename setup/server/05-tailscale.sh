#!/bin/bash

set -e

echo "=========================================="
echo "05 - Tailscale Setup"
echo "=========================================="

# Install Tailscale with SSH support
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "Enabling Tailscale with SSH and Exit Node support..."
echo "Note: You'll need to authenticate with Tailscale after running the up command"

echo "Starting Tailscale with SSH and exit node capabilities..."
sudo tailscale up --ssh --advertise-exit-node --accept-routes

echo "✅ Tailscale setup complete!"
echo "This server is now configured as:"
echo "  - SSH server (accessible from tailnet devices)"
echo "  - Exit node (can route internet traffic for other tailnet devices)"
echo ""
echo "⚠️  You may see warnings about IPv6 forwarding or UDP GRO - these are non-critical"
echo ""
echo "Next steps:"
echo "1. Go to https://login.tailscale.com/admin/machines"
echo "2. Find this server (apollo) in the machine list"
echo "3. Enable it as an exit node"
echo "4. Other devices can then use: tailscale set --exit-node=apollo"