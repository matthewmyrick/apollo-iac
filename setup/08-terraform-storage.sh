#!/bin/bash

set -e

echo "=========================================="
echo "08 - Terraform State Storage Setup"
echo "========================================="

# Check if k3s is running
if ! systemctl is-active --quiet k3s; then
  echo "Error: k3s is not running. Please run 06-k3s.sh first."
  exit 1
fi

# Create k8s directory if it doesn't exist
mkdir -p k8s

# Create the storage directory on the host
echo "Creating terraform state storage directory..."
sudo mkdir -p /var/lib/terraform-state
sudo chown $(whoami):$(whoami) /var/lib/terraform-state

# Set KUBECONFIG
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Apply the storage configuration
echo "Deploying terraform state storage..."
kubectl apply -f k8s/terraform-state-storage.yaml

# Wait for deployment to be ready
echo "Waiting for terraform state server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/terraform-state-server -n terraform-state

# Get Tailscale auth key from Vault
echo ""
echo "=========================================="
echo "Tailscale Setup"
echo "=========================================="
echo "Retrieving Tailscale auth key from Vault..."

# Check if Vault is available
if kubectl get deployment vault -n key-vault >/dev/null 2>&1; then
  # Get Vault pod and root token
  VAULT_POD=$(kubectl get pods -n key-vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
  ROOT_TOKEN=$(kubectl get secret vault-keys -n key-vault -o jsonpath='{.data.root-token}' | base64 -d)
  
  # Try to get Tailscale auth key from Vault
  TAILSCALE_AUTH_KEY=$(kubectl exec -n key-vault $VAULT_POD -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv get -field=auth_key secret/tailscale 2>/dev/null" || echo "")
  
  if [ -n "$TAILSCALE_AUTH_KEY" ]; then
    echo "✓ Successfully retrieved Tailscale auth key from Vault"
  else
    echo "⚠ Tailscale auth key not found in Vault"
    echo "Please add it using one of these methods:"
    echo "  1. Web UI: https://vault.tailnet"
    echo "  2. CLI: vault kv put secret/tailscale auth_key=\"YOUR_KEY\""
    echo "  3. See VAULT_USAGE.md for detailed instructions"
    echo ""
    read -p "Enter your Tailscale auth key manually: " TAILSCALE_AUTH_KEY
  fi
else
  echo "⚠ Vault not found. Please run 07-key-vault.sh first."
  echo "For now, entering auth key manually:"
  echo "Get one from: https://login.tailscale.com/admin/settings/keys"
  echo ""
  read -p "Enter your Tailscale auth key: " TAILSCALE_AUTH_KEY
fi

if [ -z "$TAILSCALE_AUTH_KEY" ]; then
  echo "Warning: No auth key provided. Skipping Tailscale ingress setup."
  echo "You can manually apply it later with:"
  echo "  sed -i 's/YOUR_TAILSCALE_AUTH_KEY_HERE/YOUR_ACTUAL_KEY/' k8s/tailscale-ingress.yaml"
  echo "  kubectl apply -f k8s/tailscale-ingress.yaml"
else
  echo "Applying Tailscale ingress with your auth key..."
  sed "s/YOUR_TAILSCALE_AUTH_KEY_HERE/$TAILSCALE_AUTH_KEY/" k8s/tailscale-ingress.yaml | kubectl apply -f -
  echo "Tailscale ingress applied successfully!"
fi
echo ""

# Create minio bucket for terraform state
echo "Creating terraform state bucket..."
# The line below has been updated from `mc config host add` to `mc alias set`
kubectl exec -n terraform-state deployment/terraform-state-server -- mc alias set local http://localhost:9000 terraform terraform-state-password
kubectl exec -n terraform-state deployment/terraform-state-server -- mc mb local/terraform-state || echo "Bucket may already exist"

# Get service information
echo ""
echo "=========================================="
echo "Terraform State Storage Setup Complete!"
echo "=========================================="
echo "MinIO API: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):$(kubectl get svc terraform-state-service -n terraform-state -o jsonpath='{.spec.ports[0].nodePort}')"
echo "MinIO Console: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):$(kubectl get svc terraform-state-service -n terraform-state -o jsonpath='{.spec.ports[1].nodePort}')"
echo ""
echo "Credentials:"
echo "  Access Key: terraform"
echo "  Secret Key: terraform-state-password"
echo ""
echo "After setting up Tailscale ingress, you can access via:"
echo "  API: https://terraform-state.tailnet"
echo "  Console: https://terraform-state.tailnet/console"
echo ""
echo "Terraform backend configuration:"
echo "terraform {"
echo "  backend \"s3\" {"
echo "    endpoint = \"https://terraform-state.tailnet\""
echo "    bucket = \"terraform-state\""
echo "    key = \"path/to/terraform.tfstate\""
echo "    region = \"us-east-1\""
echo "    access_key = \"terraform\""
echo "    secret_key = \"terraform-state-password\""
echo "    skip_credentials_validation = true"
echo "    skip_metadata_api_check = true"
echo "    skip_region_validation = true"
echo "    force_path_style = true"
echo "  }"
echo "}"
