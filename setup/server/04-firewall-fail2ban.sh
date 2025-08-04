#!/bin/bash

set -e

echo "=========================================="
echo "04 - Firewall and Fail2ban Setup"
echo "=========================================="
echo "NOTE: This script will configure the firewall to allow ALL traffic from your tailnet."

# Configure firewall
echo "Configuring UFW firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 41641/udp # Tailscale coordination port

# The next rule allows all incoming connections (SSH, web, etc.) from your Tailscale network.
# This makes services accessible to your devices without exposing them to the public internet.
echo "Allowing all incoming traffic on the 'tailscale0' interface..."
sudo ufw allow in on tailscale0

# Enable the firewall with the new rules
sudo ufw --force enable

# Configure fail2ban for SSH security
echo "Configuring fail2ban..."
sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "✅ Firewall and fail2ban setup complete!"
echo "All services on this server are now accessible to devices in your tailnet."

