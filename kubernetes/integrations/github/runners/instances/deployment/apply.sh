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
  echo "║      GitHub Actions Runners Setup (Step 3/3)         ║"
  echo "║         Deploy actual runner instances                ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_FILE="${SCRIPT_DIR}/argocd.yaml"

check_prerequisites() {
  log_info "Checking prerequisites..."
  
  # Check if controller is deployed
  if ! kubectl get deployment gh-actions-runner-controller -n github-runners &>/dev/null; then
    log_error "Controller not found. Please deploy controller first:"
    echo "  cd ../controller/deployment && ./apply.sh"
    exit 1
  fi
  
  # Check if CRDs are installed
  if ! kubectl get crd runnerdeployments.actions.summerwind.dev &>/dev/null; then
    log_error "CRDs not found. Controller may still be installing. Please wait and try again."
    exit 1
  fi
  
  log_success "Prerequisites met"
}

deploy_runners() {
  log_info "Deploying GitHub Actions Runners..."
  
  if [[ ! -f "$ARGOCD_FILE" ]]; then
    log_error "argocd.yaml file not found at: $ARGOCD_FILE"
    exit 1
  fi
  
  kubectl apply -f "$ARGOCD_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_success "Runners ArgoCD application applied successfully"
    log_info "Waiting for runners to be created..."
    sleep 10
  else
    log_error "Failed to apply runners application"
    exit 1
  fi
}

show_status() {
  echo ""
  log_info "Runners Status:"
  echo ""
  
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application github-actions-runners -n argocd -o wide 2>/dev/null || log_warning "Application not found"
  echo ""
  
  echo -e "${BLUE}Runner Deployments:${NC}"
  kubectl get runnerdeployments -n github-runners 2>/dev/null || log_info "No runner deployments yet"
  echo ""
  
  echo -e "${BLUE}Active Runners:${NC}"
  kubectl get runners -n github-runners 2>/dev/null || log_info "No active runners yet"
  echo ""
  
  echo -e "${BLUE}Runner Pods:${NC}"
  kubectl get pods -n github-runners -l app=apollo-github-runners 2>/dev/null || log_info "No runner pods yet"
  echo ""
  
  echo -e "${BLUE}Autoscaler:${NC}"
  kubectl get hra -n github-runners 2>/dev/null || log_info "No autoscaler yet"
}

print_completion() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      GitHub Actions Setup Complete! (3/3) 🚀${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}Your runners are now available with labels:${NC}"
  echo "  - apollo"
  echo "  - self-hosted"
  echo "  - k3s"
  echo "  - linux"
  echo "  - x64"
  echo ""
  echo -e "${BLUE}Use in your workflows:${NC}"
  echo "  runs-on: [self-hosted, apollo]"
  echo ""
  echo -e "${BLUE}Monitor runners:${NC}"
  echo "  kubectl get runners -n github-runners"
  echo "  kubectl get pods -n github-runners"
  echo "  kubectl logs -n github-runners -l app=apollo-github-runners"
  echo ""
  echo -e "${BLUE}ArgoCD UI:${NC} http://home.apollo.io:30969"
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    check_prerequisites
    deploy_runners
    show_status
    print_completion
    ;;
    
  status)
    show_status
    ;;
    
  remove)
    log_warning "Removing runners..."
    kubectl delete -f "$ARGOCD_FILE" --ignore-not-found=true
    log_success "Runners application removed"
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    exit 1
    ;;
esac