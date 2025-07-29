#!/bin/bash

set -e

echo "=========================================="
echo "07 - Key Vault Storage Setup"
echo "========================================="

# Check if k3s is running
if ! systemctl is-active --quiet k3s; then
  echo "Error: k3s is not running. Please run 06-k3s.sh first."
  exit 1
fi

# Create k8s directory if it doesn't exist
mkdir -p k8s

# Set KUBECONFIG
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Create namespace for key vault
echo "Creating key-vault namespace..."
kubectl create namespace key-vault --dry-run=client -o yaml | kubectl apply -f -

# Deploy Vault
echo "Deploying HashiCorp Vault..."
kubectl apply -f k8s/vault-storage.yaml

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/vault -n key-vault

# Initialize Vault
echo "Initializing Vault..."
sleep 10  # Give Vault a moment to fully start

# Get the Vault pod name
VAULT_POD=$(kubectl get pods -n key-vault -l app=vault -o jsonpath='{.items[0].metadata.name}')

# Initialize Vault and capture output
echo "Initializing Vault with 1 key share and threshold of 1..."
INIT_OUTPUT=$(kubectl exec -n key-vault $VAULT_POD -- vault operator init -key-shares=1 -key-threshold=1 -format=json)

# Extract unseal key and root token
UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')

# Store these securely in k8s secrets
echo "Storing Vault credentials in Kubernetes secrets..."
kubectl create secret generic vault-keys -n key-vault \
  --from-literal=unseal-key="$UNSEAL_KEY" \
  --from-literal=root-token="$ROOT_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# Unseal Vault
echo "Unsealing Vault..."
kubectl exec -n key-vault $VAULT_POD -- vault operator unseal $UNSEAL_KEY

# Configure Vault
echo "Configuring Vault..."
kubectl exec -n key-vault $VAULT_POD -- vault login $ROOT_TOKEN

# Enable KV v2 secrets engine
kubectl exec -n key-vault $VAULT_POD -- vault secrets enable -path=secret kv-v2

# Create policy for secrets access
kubectl exec -n key-vault $VAULT_POD -- vault policy write secrets-policy - <<EOF
path "secret/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/metadata/*" {
  capabilities = ["list", "delete"]
}
EOF

echo ""
echo "=========================================="
echo "Key Vault Setup Complete!"
echo "=========================================="
echo "Vault is accessible at:"
echo "  Internal: http://vault.key-vault.svc.cluster.local:8200"
echo "  NodePort: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):$(kubectl get svc vault-service -n key-vault -o jsonpath='{.spec.ports[0].nodePort}')"
echo ""
echo "Root Token: $ROOT_TOKEN"
echo "Unseal Key: $UNSEAL_KEY"
echo ""
echo "IMPORTANT: Save these credentials securely!"
echo "They are also stored in the 'vault-keys' Kubernetes secret in the key-vault namespace."
echo ""