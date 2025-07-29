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

echo "k3s installation complete!"
echo "Node token for joining additional nodes: $(sudo cat /var/lib/rancher/k3s/server/node-token)"
echo "Kubeconfig location: /etc/rancher/k3s/k3s.yaml"