#!/bin/bash

set -e

echo "=========================================="
echo "07 - ArgoCD Setup"
echo "=========================================="

# Check if k3s is running
if ! systemctl is-active --quiet k3s; then
  echo "Error: k3s is not running. Please run 06-k3s.sh first."
  exit 1
fi

# Set KUBECONFIG
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check current context and switch to apollo if needed
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "apollo" ]; then
  echo "Switching kubectl context to 'apollo'..."
  kubectl config use-context apollo || {
    echo "Error: 'apollo' context not found. Please ensure the k3s cluster context is named 'apollo'."
    echo "Current contexts available:"
    kubectl config get-contexts
    exit 1
  }
fi

echo "Using kubectl context: $(kubectl config current-context)"

# Create namespace for ArgoCD
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-redis -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-dex-server -n argocd

# Patch ArgoCD server to use NodePort on port 6969
echo "Configuring ArgoCD server with NodePort 6969..."
kubectl patch svc argocd-server -n argocd --type='json' -p='[
  {"op": "replace", "path": "/spec/type", "value": "NodePort"},
  {"op": "replace", "path": "/spec/ports/0/nodePort", "value": 6969},
  {"op": "replace", "path": "/spec/ports/1/nodePort", "value": 6970}
]'

# Wait for pods to be ready
echo "Waiting for all ArgoCD pods to be running..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get the initial admin password
echo "Getting initial admin password..."
INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Create a ConfigMap for user configuration
echo "Creating user configuration..."
kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  accounts.matthewmyrick: apiKey, login
  accounts.matthewmyrick.enabled: "true"
EOF

# Restart ArgoCD server to pick up the new user
echo "Restarting ArgoCD server..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Wait a bit for the server to fully restart
sleep 10

# Create argocd-cli secret to store the admin password temporarily
kubectl create secret generic argocd-admin-temp -n argocd \
  --from-literal=password="$INITIAL_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Use kubectl exec to set the password for matthewmyrick user
echo "Setting password for matthewmyrick user..."
ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')

# First login as admin and then create the user password
kubectl exec -n argocd $ARGOCD_POD -- argocd login localhost:8080 --insecure --username admin --password "$INITIAL_PASSWORD"
kubectl exec -n argocd $ARGOCD_POD -- argocd account update-password --account matthewmyrick --new-password "IHateProductManagers!" --current-password "$INITIAL_PASSWORD"

# Configure RBAC for the new user
echo "Configuring RBAC for matthewmyrick user..."
kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, certificates, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, gpgkeys, *, *, allow
    g, matthewmyrick, role:admin
EOF

# Restart ArgoCD server one more time to ensure all configs are loaded
echo "Final restart of ArgoCD server..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Clean up temporary secret
kubectl delete secret argocd-admin-temp -n argocd --ignore-not-found

# Get the node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")

echo ""
echo "=========================================="
echo "ArgoCD Setup Complete!"
echo "=========================================="
echo "ArgoCD is accessible at:"
echo "  NodePort: http://$NODE_IP:6969"
if [ "$TAILSCALE_IP" != "N/A" ]; then
  echo "  Tailscale: http://$TAILSCALE_IP:6969"
fi
echo ""
echo "Login Credentials:"
echo "  Username: matthewmyrick"
echo "  Password: IHateProductManagers!"
echo ""
echo "Admin Credentials (if needed):"
echo "  Username: admin"
echo "  Password: $INITIAL_PASSWORD"
echo ""
echo "IMPORTANT: The admin password is also stored in the 'argocd-initial-admin-secret' in the argocd namespace."
echo "Consider changing both passwords after first login!"
echo ""