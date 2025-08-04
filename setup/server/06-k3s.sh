#!/bin/bash

set -e

echo "=========================================="
echo "06 - k3s Kubernetes Setup"
echo "=========================================="

# Install k3s
echo "Installing k3s Kubernetes..."
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sudo systemctl enable k3s
sudo systemctl start k3s

# Wait for k3s to fully start
sleep 30

# Set up kubeconfig permissions
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Set KUBECONFIG for Tailscale operator installation
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install Tailscale Operator
echo "Installing Tailscale Operator..."
kubectl apply -f https://raw.githubusercontent.com/tailscale/tailscale/main/cmd/k8s-operator/deploy/manifests/operator.yaml

# Wait for Tailscale operator to be ready
echo "Waiting for Tailscale operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/operator -n tailscale

# Prompt for Tailscale auth key
echo ""
echo "==========================================="
echo "Tailscale Auth Key Setup"
echo "==========================================="
echo "To enable Tailscale ingress, you need to provide a Tailscale auth key."
echo "Get your auth key from: https://login.tailscale.com/admin/settings/keys"
echo ""
read -p "Enter your Tailscale auth key (or press Enter to skip): " TAILSCALE_AUTH_KEY

if [ ! -z "$TAILSCALE_AUTH_KEY" ]; then
  echo "Creating Tailscale auth secrets for namespaces..."
  
  # Create key-vault namespace if it doesn't exist
  kubectl create namespace key-vault --dry-run=client -o yaml | kubectl apply -f -
  
  # Create terraform-state namespace if it doesn't exist  
  kubectl create namespace terraform-state --dry-run=client -o yaml | kubectl apply -f -
  
  # Create Tailscale auth secret for key-vault namespace
  kubectl create secret generic tailscale-auth -n key-vault \
    --from-literal=TS_AUTHKEY="$TAILSCALE_AUTH_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Create Tailscale auth secret for terraform-state namespace
  kubectl create secret generic tailscale-auth -n terraform-state \
    --from-literal=TS_AUTHKEY="$TAILSCALE_AUTH_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
    
  echo "Tailscale auth secrets created successfully!"
else
  echo "Skipping Tailscale auth key setup. You can create the secrets manually later."
fi

echo ""
echo "==========================================="
echo "k3s installation complete!"
echo "==========================================="
echo "Node token for joining additional nodes: $(sudo cat /var/lib/rancher/k3s/server/node-token)"
echo "Kubeconfig location: /etc/rancher/k3s/k3s.yaml"