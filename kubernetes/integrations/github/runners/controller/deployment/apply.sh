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

print_banner() {
  echo -e "${BLUE}"
  echo "╔═══════════════════════════════════════════════════════╗"
  echo "║  GitHub Runner Scale Set Controller (Step 2/3)       ║"
  echo "║     Deploy gha-runner-scale-set-controller           ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_FILE="${SCRIPT_DIR}/argocd.yaml"

check_prerequisites() {
  log_info "Checking prerequisites..."
  
  # Check if RBAC is deployed
  if ! kubectl get serviceaccount actions-runner-controller -n github-runners &>/dev/null; then
    log_error "RBAC resources not found. Please deploy RBAC first:"
    echo "  cd ../rbac/deployment && ./apply.sh"
    exit 1
  fi
  
  log_success "RBAC resources found"
}

check_github_token() {
  log_info "Checking GitHub token secret..."
  
  if kubectl get secret controller-manager -n github-runners &>/dev/null; then
    log_success "GitHub token secret exists"
  else
    log_error "GitHub token secret not found. Please deploy RBAC first:"
    echo "  cd ../rbac/deployment && ./apply.sh"
    exit 1
  fi
}

deploy_controller() {
  log_info "Deploying GitHub Actions Controller..."
  
  if [[ ! -f "$ARGOCD_FILE" ]]; then
    log_error "argocd.yaml file not found at: $ARGOCD_FILE"
    exit 1
  fi
  
  kubectl apply -f "$ARGOCD_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_success "Controller ArgoCD application applied successfully"
    log_info "Waiting for controller to be ready..."
    
    # Wait for deployment to be ready (may take a few minutes)
    log_info "This may take a few minutes for Helm chart to deploy..."
    kubectl wait --for=condition=available --timeout=300s deployment/gha-runner-scale-set-controller -n github-runners 2>/dev/null || {
      log_warning "Deployment not ready yet, but application was created successfully"
    }
  else
    log_error "Failed to apply controller application"
    exit 1
  fi
}

show_status() {
  echo ""
  log_info "Controller Status:"
  echo ""
  
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application github-actions-controller -n argocd -o wide 2>/dev/null || log_warning "Application not found"
  echo ""
  
  echo -e "${BLUE}Controller Deployment:${NC}"
  kubectl get deployment gha-runner-scale-set-controller -n github-runners 2>/dev/null || log_info "Deployment not created yet"
  echo ""
  
  echo -e "${BLUE}Controller Pods:${NC}"
  kubectl get pods -n github-runners -l app.kubernetes.io/name=gha-runner-scale-set-controller 2>/dev/null || log_info "No controller pods yet"
  echo ""
  
  echo -e "${BLUE}Custom Resource Definitions:${NC}"
  kubectl get crd | grep actions.github.com 2>/dev/null || log_info "CRDs not installed yet"
}

print_next_steps() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      Controller Setup Complete! (2/3) ✅${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}Next steps:${NC}"
  echo "3. Deploy the runners: cd ../instances/deployment && ./apply.sh"
  echo ""
  echo -e "${BLUE}Monitor deployment:${NC}"
  echo "  kubectl get applications -n argocd"
  echo "  kubectl get pods -n github-runners"
  echo "  kubectl logs -n github-runners deployment/gha-runner-scale-set-controller"
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    check_prerequisites
    check_github_token
    deploy_controller
    show_status
    print_next_steps
    ;;
    
  status)
    show_status
    ;;
    
  remove)
    log_warning "Removing controller..."
    kubectl delete -f "$ARGOCD_FILE" --ignore-not-found=true
    log_success "Controller application removed"
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    exit 1
    ;;
esac