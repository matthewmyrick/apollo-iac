#!/bin/bash

set -e

# Colors and formatting for pretty logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Pretty logging functions
log_info() {
  echo -e "${BLUE}ℹ️  ${NC}${1}"
}

log_success() {
  echo -e "${GREEN}✅ ${NC}${1}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  ${NC}${1}"
}

log_error() {
  echo -e "${RED}❌ ${NC}${1}"
}

log_step() {
  echo -e "\n${PURPLE}▶ ${BOLD}${1}${NC}"
}

print_banner() {
  echo -e "${CYAN}"
  echo "╔═══════════════════════════════════════════════════════╗"
  echo "║        GitHub Actions Runner Integration              ║"
  echo "║           Deploy via ArgoCD                           ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_FILE="${SCRIPT_DIR}/argocd.yaml"

# Check if argocd.yaml exists
if [[ ! -f "$ARGOCD_FILE" ]]; then
  log_error "argocd.yaml file not found at: $ARGOCD_FILE"
  exit 1
fi

# Function to check if kubectl is available and connected
check_prerequisites() {
  log_step "Checking prerequisites"
  
  if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
  fi
  
  if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

# Function to check GitHub token secret
check_github_token() {
  log_step "Checking GitHub token secret"
  
  if kubectl get secret controller-manager -n github-runners &> /dev/null; then
    log_success "GitHub token secret exists"
  else
    log_warning "GitHub token secret not found"
    if [[ -z "$GITHUB_TOKEN" ]]; then
      log_error "Please set GITHUB_TOKEN environment variable and run:"
      echo "  export GITHUB_TOKEN=your_github_token_here"
      echo "  kubectl create secret generic controller-manager \\"
      echo "    --namespace=github-runners \\"
      echo "    --from-literal=github_token=\"\$GITHUB_TOKEN\""
      exit 1
    else
      log_info "Creating GitHub token secret..."
      kubectl create namespace github-runners --dry-run=client -o yaml | kubectl apply -f -
      kubectl create secret generic controller-manager \
        --namespace=github-runners \
        --from-literal=github_token="$GITHUB_TOKEN" \
        --dry-run=client -o yaml | kubectl apply -f -
      log_success "GitHub token secret created"
    fi
  fi
}

# Function to deploy GitHub runners via ArgoCD
deploy_runners() {
  log_step "Deploying GitHub Actions Runners via ArgoCD"
  
  # Apply the ArgoCD application
  kubectl apply -f "$ARGOCD_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_success "ArgoCD application applied successfully"
  else
    log_error "Failed to apply ArgoCD application"
    exit 1
  fi
  
  log_info "ArgoCD will now sync and deploy the GitHub runners"
  log_info "Monitor progress in ArgoCD UI or use: kubectl get applications -n argocd"
}

# Function to check deployment status
check_status() {
  log_step "Checking deployment status"
  
  # Check ArgoCD application
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application github-actions-runners -n argocd -o wide 2>/dev/null || {
    log_warning "ArgoCD application not found"
    return 1
  }
  
  echo ""
  
  # Check if namespace exists
  if kubectl get namespace github-runners &> /dev/null; then
    echo -e "${BLUE}GitHub Runners Namespace:${NC}"
    kubectl get pods -n github-runners 2>/dev/null || log_info "No pods yet (ArgoCD may still be syncing)"
    echo ""
    
    echo -e "${BLUE}Runner Deployments:${NC}"
    kubectl get runnerdeployments -n github-runners 2>/dev/null || log_info "No runner deployments yet"
    echo ""
    
    echo -e "${BLUE}Active Runners:${NC}"
    kubectl get runners -n github-runners 2>/dev/null || log_info "No active runners yet"
  else
    log_info "github-runners namespace not created yet (ArgoCD may still be syncing)"
  fi
}

# Function to remove GitHub runners
remove_runners() {
  log_step "Removing GitHub Actions Runners"
  
  log_warning "This will remove the ArgoCD application and all GitHub runners"
  read -p "Are you sure? (y/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete -f "$ARGOCD_FILE" --ignore-not-found=true
    log_success "ArgoCD application removed"
    log_info "ArgoCD will handle cleanup of deployed resources"
  else
    log_info "Operation cancelled"
  fi
}

# Function to show usage information
show_usage() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      GitHub Runners Integration Complete! 🚀${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}Monitor deployment:${NC}"
  echo "  ArgoCD UI: http://home.apollo.io:30969"
  echo "  kubectl get applications -n argocd"
  echo "  kubectl get pods -n github-runners"
  echo ""
  echo -e "${BLUE}Check runner status:${NC}"
  echo "  kubectl get runners -n github-runners"
  echo "  kubectl get runnerdeployments -n github-runners"
  echo ""
  echo -e "${BLUE}View logs:${NC}"
  echo "  kubectl logs -n github-runners -l app=apollo-github-runners"
  echo ""
  echo -e "${BLUE}Runner labels for workflows:${NC}"
  echo "  runs-on: [self-hosted, apollo]"
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    check_prerequisites
    check_github_token
    deploy_runners
    check_status
    show_usage
    ;;
    
  status)
    check_status
    ;;
    
  remove)
    remove_runners
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    echo "  deploy - Deploy GitHub runners via ArgoCD (default)"
    echo "  status - Show current deployment status"
    echo "  remove - Remove GitHub runners deployment"
    exit 1
    ;;
esac