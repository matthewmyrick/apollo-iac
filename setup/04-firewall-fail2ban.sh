#!/bin/bash

set -e

echo "=========================================="
echo "04 - Firewall and Fail2ban Setup"
echo "=========================================="

# Configure firewall
echo "Configuring UFW firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 41641/udp  # Tailscale port

# Wait for Tailscale interface to be available after connection
echo "Note: SSH will be restricted to Tailscale interface only"
echo "After connecting to Tailscale, run these commands to secure SSH:"
echo "sudo ufw allow in on tailscale0 to any port 22"
echo "sudo ufw delete allow ssh  # Remove the general SSH rule"

sudo ufw --force enable

# Configure fail2ban
echo "Configuring fail2ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
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

echo "Firewall and fail2ban setup complete!"