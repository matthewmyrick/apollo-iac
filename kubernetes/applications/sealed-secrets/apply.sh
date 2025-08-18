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
  echo "║           Sealed Secrets Deployment                   ║"
  echo "║        Lightweight GitOps-friendly secrets            ║"
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
  
  log_success "Prerequisites check passed"
}

deploy_sealed_secrets() {
  log_step "Deploying Sealed Secrets via ArgoCD"
  
  if [[ ! -f "${NAMESPACE_FILE}" ]]; then
    log_error "namespace.yaml file not found at: ${NAMESPACE_FILE}"
    exit 1
  fi
  
  if [[ ! -f "${ARGOCD_FILE}" ]]; then
    log_error "argocd.yaml file not found at: ${ARGOCD_FILE}"
    exit 1
  fi
  
  kubectl apply -f "${NAMESPACE_FILE}"
  kubectl apply -f "${ARGOCD_FILE}"
  
  if [[ $? -eq 0 ]]; then
    log_success "Sealed Secrets ArgoCD application applied successfully"
    log_info "Waiting for controller to be ready..."
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets 2>/dev/null || {
      log_warning "Deployment not ready yet, but application was created successfully"
    }
  else
    log_error "Failed to apply Sealed Secrets application"
    exit 1
  fi
}

backup_master_key() {
  log_step "Backing up master key"
  
  # Wait a bit for the secret to be created
  sleep 10
  
  if kubectl get secret sealed-secrets-key -n sealed-secrets &>/dev/null; then
    kubectl get secret sealed-secrets-key -n sealed-secrets -o yaml > "${SCRIPT_DIR}/sealed-secrets-master-key-backup.yaml"
    log_success "Master key backed up to: ${SCRIPT_DIR}/sealed-secrets-master-key-backup.yaml"
    echo ""
    log_warning "🔐 IMPORTANT: Store this master key backup securely!"
    echo "   - Copy to external drive"
    echo "   - Store in password manager"  
    echo "   - DO NOT commit to Git"
    echo ""
    echo "   This key is needed to decrypt secrets if cluster is rebuilt."
  else
    log_warning "Master key not found yet, controller may still be starting"
  fi
}

install_kubeseal() {
  log_step "Checking kubeseal CLI"
  
  if command -v kubeseal &> /dev/null; then
    local version=$(kubeseal --version 2>&1 | grep -o 'v[0-9.]*' || echo "unknown")
    log_success "kubeseal CLI already installed (${version})"
  else
    log_info "Installing kubeseal CLI..."
    
    if command -v brew &> /dev/null; then
      brew install kubeseal
      log_success "kubeseal installed via Homebrew"
    else
      log_warning "Homebrew not found. Install kubeseal manually:"
      echo "  # Download from: https://github.com/bitnami-labs/sealed-secrets/releases"
      echo "  # Or use package manager of your choice"
    fi
  fi
}

show_usage() {
cat <<'EOF'

${GREEN}═══════════════════════════════════════════════════════════${NC}
${GREEN}      Sealed Secrets Setup Complete! 🔐${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

${BLUE}How to create secrets:${NC}

${CYAN}# Create a secret${NC}
kubectl create secret generic mysecret \
  --from-literal=key=value \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > mysecret-sealed.yaml

${CYAN}# Apply the sealed secret${NC}
kubectl apply -f mysecret-sealed.yaml

${CYAN}# The sealed secret is safe to commit to Git${NC}
git add mysecret-sealed.yaml
git commit -m 'Add encrypted secret'

${BLUE}CLI Examples:${NC}
${CYAN}# Database password${NC}
echo -n 'supersecret' | kubectl create secret generic db-password \
  --from-file=password=/dev/stdin --dry-run=client -o yaml | \
  kubeseal -o yaml > db-password-sealed.yaml

${CYAN}# API key${NC}
kubectl create secret generic api-keys \
  --from-literal=github_token=ghp_xxxxx \
  --from-literal=docker_password=xxxxx \
  --dry-run=client -o yaml | kubeseal -o yaml > api-keys-sealed.yaml

${BLUE}Monitor:${NC}
  kubectl get pods -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets
  kubectl logs -n sealed-secrets deployment/sealed-secrets-controller
EOF
}

check_status() {
  log_step "Checking Sealed Secrets status"
  
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application sealed-secrets -n argocd -o wide 2>/dev/null || log_warning "Application not found"
  echo ""
  
  echo -e "${BLUE}Controller Deployment:${NC}"
  kubectl get deployment sealed-secrets-controller -n sealed-secrets 2>/dev/null || log_info "Deployment not created yet"
  echo ""
  
  echo -e "${BLUE}Controller Pods:${NC}"
  kubectl get pods -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets 2>/dev/null || log_info "No controller pods yet"
  echo ""
  
  echo -e "${BLUE}Master Key:${NC}"
  kubectl get secret sealed-secrets-key -n sealed-secrets 2>/dev/null || log_info "Master key not created yet"
}

remove_sealed_secrets() {
  log_step "Removing Sealed Secrets"
  
  log_warning "This will remove Sealed Secrets controller and make existing sealed secrets unusable"
  read -p "Are you sure? (y/N): " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete -f "${ARGOCD_FILE}" --ignore-not-found=true
    log_success "Sealed Secrets application removed"
    log_info "ArgoCD will handle cleanup of deployed resources"
  else
    log_info "Operation cancelled"
  fi
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    check_prerequisites
    deploy_sealed_secrets
    backup_master_key
    install_kubeseal
    check_status
    show_usage
    ;;
    
  status)
    check_status
    ;;
    
  remove)
    remove_sealed_secrets
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    echo "  deploy - Deploy Sealed Secrets (default)"
    echo "  status - Show current status"
    echo "  remove - Remove Sealed Secrets"
    exit 1
    ;;
esac
