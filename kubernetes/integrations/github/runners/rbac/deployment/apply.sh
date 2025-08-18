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
  echo "║       GitHub Actions RBAC Setup (Step 1/3)           ║"
  echo "║         Deploy RBAC resources first                   ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_FILE="${SCRIPT_DIR}/argocd.yaml"

deploy_rbac() {
  log_info "Deploying GitHub Actions RBAC resources..."
  
  if [[ ! -f "$ARGOCD_FILE" ]]; then
    log_error "argocd.yaml file not found at: $ARGOCD_FILE"
    exit 1
  fi
  
  kubectl apply -f "$ARGOCD_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_success "RBAC ArgoCD application applied successfully"
    log_info "Waiting for RBAC resources to be created..."
    sleep 10
    
    # Check if resources were created
    if kubectl get serviceaccount actions-runner-controller -n github-runners &>/dev/null; then
      log_success "RBAC resources deployed successfully"
    else
      log_warning "RBAC resources may still be syncing"
    fi
  else
    log_error "Failed to apply RBAC application"
    exit 1
  fi
}

show_status() {
  echo ""
  log_info "RBAC Status:"
  echo ""
  
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application github-actions-rbac -n argocd -o wide 2>/dev/null || log_warning "Application not found"
  echo ""
  
  echo -e "${BLUE}RBAC Resources:${NC}"
  kubectl get serviceaccount actions-runner-controller -n github-runners 2>/dev/null || log_info "ServiceAccount not created yet"
  kubectl get clusterrole actions-runner-controller 2>/dev/null || log_info "ClusterRole not created yet"
  kubectl get clusterrolebinding actions-runner-controller 2>/dev/null || log_info "ClusterRoleBinding not created yet"
}

print_next_steps() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      RBAC Setup Complete! (1/3) ✅${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}Next steps:${NC}"
  echo "2. Deploy the controller: cd ../controller/deployment && ./apply.sh"
  echo "3. Deploy the runners: cd ../instances/deployment && ./apply.sh"
  echo ""
  echo -e "${BLUE}Or run the deployment script that does all three:${NC}"
  echo "cd ../../deployment && ./apply.sh deploy"
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    deploy_rbac
    show_status
    print_next_steps
    ;;
    
  status)
    show_status
    ;;
    
  remove)
    log_warning "Removing RBAC resources..."
    kubectl delete -f "$ARGOCD_FILE" --ignore-not-found=true
    log_success "RBAC application removed"
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    exit 1
    ;;
esac