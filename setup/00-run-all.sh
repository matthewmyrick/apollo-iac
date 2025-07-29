#!/bin/bash

set -e

echo "=========================================="
echo "Apollo Homeserver Setup Script"
echo "=========================================="
echo "This script will configure:"
echo "- Shell environment (zsh + dotfiles)"
echo "- SSH access and security"
echo "- Tailscale VPN with SSH integration"
echo "- k3s Kubernetes cluster"
echo "- Terraform for infrastructure management"
echo "=========================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root for security reasons."
   echo "Please run as a regular user with sudo privileges."
   exit 1
fi

# Check for sudo privileges
if ! sudo -n true 2>/dev/null; then
    echo "This script requires sudo privileges. Please ensure your user has sudo access."
    exit 1
fi

# Get the directory where this script is located
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Run all setup scripts in order
echo "Starting modular setup process..."

scripts=(
    "01-system-packages.sh"
    "02-dotfiles.sh" 
    "03-ssh-security.sh"
    "04-firewall-fail2ban.sh"
    "05-tailscale.sh"
    "06-k3s.sh"
    "07-terraform-setup.sh"
)

for script in "${scripts[@]}"; do
    script_path="$SETUP_DIR/$script"
    if [[ -f "$script_path" ]]; then
        echo ""
        echo "Executing $script..."
        chmod +x "$script_path"
        "$script_path"
        echo "$script completed successfully!"
    else
        echo "Warning: $script not found at $script_path"
    fi
done

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo "Next steps:"
echo "1. Run 'sudo tailscale up --ssh' to connect and enable SSH"
echo "2. Authenticate via the Tailscale web interface"
echo "3. Secure SSH to Tailscale only:"
echo "   sudo ufw allow in on tailscale0 to any port 22"
echo "   sudo ufw delete allow ssh"
echo "4. Access k3s cluster:"
echo "   kubectl get nodes"
echo "5. Test Terraform:"
echo "   terraform version"
echo "=========================================="

echo "Setup script completed successfully!"
echo "Services installed:"
echo "- Shell environment (zsh + custom dotfiles)"
echo "- SSH (secured for Tailscale only)"
echo "- Tailscale VPN with SSH integration"
echo "- k3s Kubernetes cluster"
echo "- Terraform for infrastructure management"
echo ""
echo "To connect to Tailscale with SSH enabled, run: sudo tailscale up --ssh"
echo "After authentication, you can SSH from any tailnet device without managing keys!"
echo "Kubeconfig location: /etc/rancher/k3s/k3s.yaml"