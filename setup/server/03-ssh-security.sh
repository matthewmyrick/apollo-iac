#!/bin/bash

set -e

echo "=========================================="
echo "03 - SSH Security Setup"
echo "=========================================="

# Configure SSH
echo "Configuring SSH..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Create SSH directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Note: SSH keys are managed automatically by Tailscale SSH
echo "SSH keys will be managed automatically by Tailscale SSH..."

# Configure SSH security
echo "Configuring SSH security..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Create secure SSH config
sudo tee /etc/ssh/sshd_config.d/99-custom.conf > /dev/null <<EOF
# Custom SSH configuration for Apollo homeserver
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
Port 22
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Restart SSH service to apply changes
sudo systemctl restart ssh

echo "SSH security setup complete!"