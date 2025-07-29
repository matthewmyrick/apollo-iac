#!/bin/bash

set -e

echo "=========================================="
echo "07 - Terraform Setup"
echo "=========================================="

# Install HashiCorp GPG key
echo "Installing HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Verify the key's fingerprint
gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint

# Add the official HashiCorp repository to your system
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update and install Terraform
echo "Installing Terraform..."
sudo apt update
sudo apt install -y terraform

# Verify installation
echo "Verifying Terraform installation..."
terraform version

# Create terraform user for remote state management (optional)
echo "Creating terraform directory structure..."
mkdir -p ~/.terraform
mkdir -p ~/terraform-state

echo "Terraform installation complete!"
echo "Terraform version: $(terraform version -json | grep '"version"' | head -1 | cut -d'"' -f4)"