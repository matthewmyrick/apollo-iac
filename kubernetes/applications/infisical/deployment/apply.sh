#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}${1}"; }
log_success() { echo -e "${GREEN}✅ ${NC}${1}"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}${1}"; }
log_error() { echo -e "${RED}❌ ${NC}${1}"; }
log_step() { echo -e "\n${PURPLE}▶ ${BOLD}${1}${NC}"; }

print_banner() {
  echo -e "${CYAN}"
  echo "╔═══════════════════════════════════════════════════════╗"
  echo "║              Infisical Secrets Manager                ║"
  echo "║          Official Helm Chart Deployment              ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_FILE="${SCRIPT_DIR}/argocd.yaml"
NAMESPACE_FILE="${SCRIPT_DIR}/namespace.yaml"

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
  
  if ! command -v helm &> /dev/null; then
    log_warning "Helm not found, but not required for ArgoCD deployment"
  fi
  
  log_success "Prerequisites check passed"
}

setup_helm_repository() {
  log_step "Setting up Infisical Helm repository"
  
  if command -v helm &> /dev/null; then
    log_info "Adding Infisical helm repository..."
    if helm repo add infisical 'https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/' &>/dev/null; then
      log_success "Helm repository added"
    else
      log_warning "Helm repository already exists or failed to add"
    fi
    
    log_info "Updating helm repositories..."
    helm repo update &>/dev/null || log_warning "Failed to update helm repos"
    
    log_info "Available Infisical charts:"
    helm search repo infisical 2>/dev/null || log_info "Could not list charts"
  else
    log_info "Helm not available, skipping repository setup (ArgoCD will handle this)"
  fi
}

check_storage_project() {
  log_step "Checking storage ArgoCD project"
  
  if ! kubectl get appproject storage -n argocd &>/dev/null; then
    log_error "ArgoCD 'storage' project not found!"
    echo ""
    echo "Please run the ArgoCD projects setup first:"
    echo "  cd ../../argocd/projects && ./apply.sh"
    echo ""
    exit 1
  fi
  
  log_success "Storage project exists"
}

deploy_namespace() {
  log_step "Creating Infisical namespace"
  
  if [[ ! -f "$NAMESPACE_FILE" ]]; then
    log_error "Namespace file not found: $NAMESPACE_FILE"
    exit 1
  fi
  
  kubectl apply -f "$NAMESPACE_FILE"
  log_success "Namespace created"
}

deploy_infisical() {
  log_step "Deploying Infisical via ArgoCD"
  
  if [[ ! -f "$ARGOCD_FILE" ]]; then
    log_error "ArgoCD application file not found: $ARGOCD_FILE"
    exit 1
  fi
  
  kubectl apply -f "$ARGOCD_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_success "Infisical ArgoCD application applied successfully"
    log_info "Waiting for application to sync..."
    
    # Give it time to sync
    sleep 10
  else
    log_error "Failed to apply Infisical application"
    exit 1
  fi
}

show_status() {
  log_step "Infisical Status"
  
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application infisical -n argocd -o wide 2>/dev/null || log_warning "Application not found"
  echo ""
  
  echo -e "${BLUE}Infisical Pods:${NC}"
  kubectl get pods -n infisical 2>/dev/null || log_info "No pods yet"
  echo ""
  
  echo -e "${BLUE}Infisical Services:${NC}"
  kubectl get services -n infisical 2>/dev/null || log_info "Services not created yet"
}

show_access_info() {
  log_step "Access Information"
  
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      Infisical Deployment Started! 🔐${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  
  echo -e "${BLUE}Access Infisical UI:${NC}"
  echo "URL: http://home.apollo.io:30500"
  echo "Alternative: kubectl port-forward -n infisical svc/infisical-frontend 8080:3000"
  echo ""
  
  echo -e "${BLUE}First Steps:${NC}"
  echo "1. Wait for all pods to be ready (may take a few minutes)"
  echo "2. Access the web UI to create your first admin account"
  echo "3. Create an organization and project"
  echo "4. Start managing your secrets!"
  echo ""
  
  echo -e "${BLUE}Monitor Deployment:${NC}"
  echo "  kubectl get pods -n infisical --watch"
  echo "  kubectl logs -n infisical deployment/infisical-backend"
  echo "  kubectl get application infisical -n argocd"
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    check_prerequisites
    setup_helm_repository
    check_storage_project
    deploy_namespace
    deploy_infisical
    show_status
    show_access_info
    ;;
    
  status)
    show_status
    ;;
    
  remove)
    log_warning "Removing Infisical..."
    kubectl delete -f "$ARGOCD_FILE" --ignore-not-found=true
    kubectl delete namespace infisical --ignore-not-found=true
    log_success "Infisical application removed"
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    echo "  deploy - Deploy Infisical (default)"
    echo "  status - Show current status"
    echo "  remove - Remove Infisical"
    exit 1
    ;;
esac