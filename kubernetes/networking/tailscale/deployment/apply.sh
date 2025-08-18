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
  echo "║        Tailscale Kubernetes Operator Setup            ║"
  echo "║          For selective pod network access             ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_FILE="${SCRIPT_DIR}/argocd.yaml"
PROJECTS_FILE="${SCRIPT_DIR}/../../../applications/argocd/projects/config.yaml"

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
  
  if ! command -v tailscale &> /dev/null; then
    log_error "Tailscale CLI not found. Please install Tailscale first."
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

check_tailscale_auth() {
  log_step "Checking Tailscale authentication"
  
  if ! tailscale status &> /dev/null; then
    log_error "Tailscale not authenticated. Please run 'tailscale up' first."
    exit 1
  fi
  
  TAILSCALE_NODE=$(tailscale status | head -1 | awk '{print $2}')
  log_success "Tailscale authenticated as: $TAILSCALE_NODE"
}

create_tailscale_secret() {
  log_step "Creating Tailscale authentication secret"
  
  log_warning "You need a Tailscale OAuth client for the operator."
  echo ""
  echo "To create one:"
  echo "1. Go to: https://login.tailscale.com/admin/settings/oauth"
  echo "2. Generate a new OAuth client"
  echo "3. Set these scopes:"
  echo "   - devices (to manage devices)"
  echo "   - all (or specific device access)"
  echo "4. Copy the OAuth secret"
  echo ""
  
  if [[ -z "$TAILSCALE_OAUTH_SECRET" ]]; then
    log_warning "TAILSCALE_OAUTH_SECRET environment variable not set"
    echo "Please set it and rerun:"
    echo "  export TAILSCALE_OAUTH_SECRET='tskey-api-xxxxx'"
    echo "  $0"
    exit 1
  fi
  
  # Create namespace first
  kubectl create namespace tailscale-operator --dry-run=client -o yaml | kubectl apply -f -
  
  # Create the Tailscale OAuth secret (standard name expected by operator)
  kubectl create secret generic tailscale \
    --namespace=tailscale-operator \
    --from-literal=client_secret="$TAILSCALE_OAUTH_SECRET" \
    --dry-run=client -o yaml | kubectl apply -f -
    
  log_success "Tailscale OAuth secret created"
}

deploy_networking_project() {
  log_step "Deploying networking ArgoCD project"
  
  if [[ ! -f "$PROJECTS_FILE" ]]; then
    log_error "Projects file not found: $PROJECTS_FILE"
    exit 1
  fi
  
  kubectl apply -f "$PROJECTS_FILE"
  log_success "Networking project deployed"
}

deploy_tailscale_operator() {
  log_step "Deploying Tailscale operator via ArgoCD"
  
  if [[ ! -f "$ARGOCD_FILE" ]]; then
    log_error "ArgoCD application file not found: $ARGOCD_FILE"
    exit 1
  fi
  
  kubectl apply -f "$ARGOCD_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_success "Tailscale operator ArgoCD application applied successfully"
    log_info "Waiting for operator to be ready..."
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/tailscale-operator -n tailscale-operator 2>/dev/null || {
      log_warning "Deployment not ready yet, but application was created successfully"
    }
  else
    log_error "Failed to apply Tailscale operator application"
    exit 1
  fi
}

show_status() {
  log_step "Tailscale Operator Status"
  
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application tailscale-operator -n argocd -o wide 2>/dev/null || log_warning "Application not found"
  echo ""
  
  echo -e "${BLUE}Operator Deployment:${NC}"
  kubectl get deployment tailscale-operator -n tailscale-operator 2>/dev/null || log_info "Deployment not created yet"
  echo ""
  
  echo -e "${BLUE}Operator Pods:${NC}"
  kubectl get pods -n tailscale-operator -l app.kubernetes.io/name=tailscale-operator 2>/dev/null || log_info "No operator pods yet"
  echo ""
  
  echo -e "${BLUE}Tailscale Custom Resources:${NC}"
  kubectl get crd | grep tailscale 2>/dev/null || log_info "CRDs not installed yet"
}

show_usage() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      Tailscale Operator Setup Complete! 🌐${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}How to use Tailscale with pods:${NC}"
  echo ""
  echo -e "${CYAN}# Method 1: Pod annotations (for internet access)${NC}"
  echo "apiVersion: v1"
  echo "kind: Pod"
  echo "metadata:"
  echo "  annotations:"
  echo "    tailscale.com/expose: \"true\""
  echo "    tailscale.com/hostname: \"my-pod\""
  echo ""
  echo -e "${CYAN}# Method 2: Service annotations (for service exposure)${NC}"
  echo "apiVersion: v1"
  echo "kind: Service"
  echo "metadata:"
  echo "  annotations:"
  echo "    tailscale.com/expose: \"true\""
  echo "    tailscale.com/hostname: \"my-service\""
  echo ""
  echo -e "${BLUE}Next steps for GitHub Actions:${NC}"
  echo "1. Update GitHub runners to use Tailscale annotations"
  echo "2. Test connectivity to GitHub.com"
  echo "3. Run your Hello World workflow"
  echo ""
  echo -e "${BLUE}Monitor:${NC}"
  echo "  kubectl get pods -n tailscale-operator"
  echo "  kubectl logs -n tailscale-operator deployment/tailscale-operator"
  echo "  tailscale status"
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    check_prerequisites
    check_tailscale_auth
    create_tailscale_secret
    deploy_networking_project
    deploy_tailscale_operator
    show_status
    show_usage
    ;;
    
  status)
    show_status
    ;;
    
  remove)
    log_warning "Removing Tailscale operator..."
    kubectl delete -f "$ARGOCD_FILE" --ignore-not-found=true
    log_success "Tailscale operator application removed"
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    echo "  deploy - Deploy Tailscale operator (default)"
    echo "  status - Show current status"
    echo "  remove - Remove Tailscale operator"
    exit 1
    ;;
esac