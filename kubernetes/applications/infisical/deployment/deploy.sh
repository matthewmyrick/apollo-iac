#!/bin/bash

set -e

echo "🚀 Deploying Infisical using official Helm charts..."

# Create namespace
echo "📁 Creating namespace..."
kubectl apply -f namespace.yaml

# Deploy via ArgoCD
echo "🔄 Deploying via ArgoCD..."
kubectl apply -f argocd.yaml

echo "✅ Infisical deployment started!"
echo ""
echo "🔍 Monitor the deployment:"
echo "  kubectl get application infisical -n argocd"
echo "  kubectl get pods -n infisical --watch"
echo ""
echo "🌐 Access when ready:"
echo "  http://home.apollo.io:30500"