#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}${1}"; }
log_success() { echo -e "${GREEN}✅ ${NC}${1}"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}${1}"; }
log_error() { echo -e "${RED}❌ ${NC}${1}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Deploy via ArgoCD
deploy_with_argocd() {
    log_info "Deploying Llama3 via ArgoCD..."
    
    if ! kubectl apply -f "$SCRIPT_DIR/argocd.yaml"; then
        log_error "Failed to create ArgoCD application"
        exit 1
    fi
    
    log_success "ArgoCD application created successfully"
    
    # Wait for sync
    log_info "Waiting for ArgoCD to sync the application..."
    if kubectl wait --for=condition=Healthy application/llama3 -n argocd --timeout=300s 2>/dev/null; then
        log_success "Application synced and healthy"
    else
        log_warning "Application sync timeout - check ArgoCD UI for status"
    fi
}

# Direct deployment (without ArgoCD)
deploy_direct() {
    log_info "Deploying Llama3 directly to Kubernetes..."
    
    # Apply namespace
    kubectl apply -f "$SCRIPT_DIR/namespace.yaml"
    log_success "Namespace created"
    
    # Apply deployment
    kubectl apply -f "$SCRIPT_DIR/deployment.yaml"
    log_success "Deployment created"
    
    # Apply service
    kubectl apply -f "$SCRIPT_DIR/service.yaml"
    log_success "Service created"
    
    # Wait for deployment
    log_info "Waiting for Ollama deployment to be ready..."
    kubectl rollout status deployment/ollama-llama3 -n llama3 --timeout=600s
    log_success "Ollama deployment is ready"
}

# Main execution
echo ""
log_info "Llama3 Deployment Script"
echo "========================"
echo ""

# Check if ArgoCD is available
if kubectl get ns argocd &>/dev/null; then
    log_info "ArgoCD detected. Using ArgoCD for deployment."
    deploy_with_argocd
else
    log_warning "ArgoCD not found. Deploying directly to Kubernetes."
    deploy_direct
fi

echo ""
log_info "Deployment Summary:"
echo "==================="
echo "Namespace: llama3"
echo "Service: ollama-service"
echo "NodePort: 30434"
echo "Model: llama3.2:3b"
echo ""
log_info "Access the service:"
echo "  Internal: http://ollama-service.llama3.svc.cluster.local:11434"
echo "  External: http://<node-ip>:30434"
echo ""
log_info "Test the API:"
echo "  curl http://localhost:30434/api/generate -d '{"
echo '    "model": "llama3.2:3b",'
echo '    "prompt": "Hello, how are you?",'
echo '    "stream": false'
echo "  }'"
echo ""
log_info "Check model status:"
echo "  curl http://localhost:30434/api/tags"
echo ""