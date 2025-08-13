#!/bin/bash

set -e

echo "==========================================="
echo "Deploying Hello World App to Kubernetes"
echo "==========================================="

# Set kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check if Tailscale operator is running
echo "Checking Tailscale operator status..."
if ! kubectl get deployment operator -n tailscale &>/dev/null; then
    echo "❌ Tailscale operator not found. Please ensure it's installed via the k3s setup script."
    exit 1
fi

echo "✅ Tailscale operator is running"

# Create namespace if it doesn't exist
echo "Creating namespace..."
kubectl apply -f namespace.yaml

# Check if tailscale auth secret exists in hello-world namespace
if ! kubectl get secret tailscale-auth -n hello-world &>/dev/null; then
    echo "Creating Tailscale auth secret..."
    if kubectl get secret tailscale-auth -n key-vault &>/dev/null; then
        # Copy from key-vault namespace
        kubectl get secret tailscale-auth -n key-vault -o yaml | \
        sed 's/namespace: key-vault/namespace: hello-world/' | \
        kubectl apply -f -
        echo "✅ Copied Tailscale auth secret to hello-world namespace"
    else
        echo "❌ No Tailscale auth secret found. Please create one first:"
        echo "kubectl create secret generic tailscale-auth -n hello-world --from-literal=TS_AUTHKEY=\"your-auth-key\""
        exit 1
    fi
fi

# Deploy application components
echo "Deploying ConfigMap..."
kubectl apply -f configmap.yaml

echo "Deploying Service..."
kubectl apply -f service.yaml

echo "Deploying Application..."
kubectl apply -f deployment.yaml

echo "Deploying Tailscale Ingress..."
kubectl apply -f tailscale-ingress.yaml

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/hello-world-app -n hello-world

# Wait for ingress to be ready
echo "Waiting for Tailscale ingress to be ready..."
sleep 10

# Show status
echo ""
echo "==========================================="
echo "✅ Deployment Complete!"
echo "==========================================="
echo "Application Status:"
kubectl get pods -n hello-world
echo ""
echo "Ingress Status:"
kubectl get ingress -n hello-world
echo ""
echo "Service Status:"
kubectl get svc -n hello-world

echo ""
echo "Your app should be accessible at: https://www.matthewjmyrick.com"
echo ""
echo "To check Tailscale ingress status:"
echo "  kubectl describe ingress hello-world-ingress -n hello-world"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/hello-world-app -n hello-world"