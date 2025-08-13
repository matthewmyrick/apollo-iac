#!/bin/bash

set -e

echo "==========================================="
echo "Configuring Tailscale Serve for Public Access"
echo "==========================================="

# Check if the hello world app is running
if ! curl -s http://localhost:8080 >/dev/null; then
    echo "❌ Hello world app is not running on port 8080"
    echo "Please run ./deploy.sh first"
    exit 1
fi

echo "✅ Hello world app is running on port 8080"

# Configure Tailscale Serve to expose the app publicly
echo "Configuring Tailscale Serve..."

# Stop any existing serves
echo "Stopping existing Tailscale serves..."
sudo tailscale serve reset 2>/dev/null || true

# Enable HTTPS serving for www.matthewjmyrick.com domain
echo "Setting up public HTTPS serving for www.matthewjmyrick.com..."
sudo tailscale serve --bg --https=443 --hostname=www.matthewjmyrick.com http://localhost:8080

# Show current serve configuration
echo ""
echo "Current Tailscale Serve configuration:"
sudo tailscale serve status

echo ""
echo "==========================================="
echo "✅ Tailscale Serve configured!"
echo "==========================================="
echo "Your app is now accessible at: https://www.matthewjmyrick.com"
echo ""
echo "Next steps:"
echo "1. In GoDaddy, set up a CNAME record pointing www.matthewjmyrick.com to your Tailscale hostname"
echo "2. Or use an A record pointing to Tailscale's public IP for your domain"
echo ""
echo "To get your Tailscale public hostname/IP, run:"
echo "  sudo tailscale serve status"
echo ""
echo "To disable public access later, run:"
echo "  sudo tailscale serve reset"