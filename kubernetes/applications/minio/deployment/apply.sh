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
  echo "║                   MinIO Object Storage                ║"
  echo "║              S3-Compatible Blob Storage               ║"
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
  log_step "Setting up MinIO Helm repository"
  
  if command -v helm &> /dev/null; then
    log_info "Adding MinIO helm repository..."
    helm repo add minio https://charts.min.io/ 2>/dev/null || true
    log_success "Helm repository configured"
    
    log_info "Updating helm repositories..."
    helm repo update minio 2>/dev/null || log_warning "Failed to update helm repos"
    
    log_info "Available MinIO charts:"
    helm search repo minio/minio --versions | head -5 2>/dev/null || log_info "Could not list charts"
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
  log_step "Creating MinIO namespace"
  
  if [[ ! -f "$NAMESPACE_FILE" ]]; then
    log_error "Namespace file not found: $NAMESPACE_FILE"
    exit 1
  fi
  
  kubectl apply -f "$NAMESPACE_FILE"
  log_success "Namespace created"
}

deploy_minio() {
  log_step "Deploying MinIO via ArgoCD"
  
  if [[ ! -f "$ARGOCD_FILE" ]]; then
    log_error "ArgoCD application file not found: $ARGOCD_FILE"
    exit 1
  fi
  
  kubectl apply -f "$ARGOCD_FILE"
  
  if [[ $? -eq 0 ]]; then
    log_success "MinIO ArgoCD application applied successfully"
    log_info "Waiting for application to sync..."
    
    # Give it time to sync
    sleep 10
  else
    log_error "Failed to apply MinIO application"
    exit 1
  fi
}

show_status() {
  log_step "MinIO Status"
  
  echo -e "${BLUE}ArgoCD Application:${NC}"
  kubectl get application minio -n argocd -o wide 2>/dev/null || log_warning "Application not found"
  echo ""
  
  echo -e "${BLUE}MinIO Pods:${NC}"
  kubectl get pods -n minio 2>/dev/null || log_info "No pods yet"
  echo ""
  
  echo -e "${BLUE}MinIO Services:${NC}"
  kubectl get services -n minio 2>/dev/null || log_info "Services not created yet"
}

show_access_info() {
  log_step "Access Information"
  
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      MinIO Object Storage Deployment Started! 🗄️${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  
  echo -e "${BLUE}Access MinIO:${NC}"
  echo "Console UI: http://home.apollo.io:30901"
  echo "S3 API:     http://home.apollo.io:30900"
  echo ""
  
  echo -e "${BLUE}Default Credentials:${NC}"
  echo "Username: admin"
  echo "Password: Apollo-MinIO-2024!"
  echo ""
  
  echo -e "${BLUE}Default Buckets:${NC}"
  echo "• apollo-backups - For system backups"
  echo "• apollo-media   - For media files"  
  echo "• apollo-logs    - For log storage"
  echo ""
  
  echo -e "${BLUE}S3 Endpoint Configuration:${NC}"
  echo "Endpoint: http://home.apollo.io:30900"
  echo "Region:   us-east-1 (default)"
  echo "SSL:      false (development setup)"
  echo ""
  
  echo -e "${BLUE}Monitor Deployment:${NC}"
  echo "  kubectl get pods -n minio --watch"
  echo "  kubectl logs -n minio deployment/minio"
  echo "  kubectl get application minio -n argocd"
}

# Main execution
print_banner

case "${1:-deploy}" in
  deploy)
    check_prerequisites
    setup_helm_repository
    check_storage_project
    deploy_namespace
    deploy_minio
    show_status
    show_access_info
    ;;
    
  status)
    show_status
    ;;
    
  remove)
    log_warning "Removing MinIO..."
    kubectl delete -f "$ARGOCD_FILE" --ignore-not-found=true
    kubectl delete namespace minio --ignore-not-found=true
    log_success "MinIO application removed"
    ;;
    
  *)
    echo "Usage: $0 [deploy|status|remove]"
    echo "  deploy - Deploy MinIO (default)"
    echo "  status - Show current status"
    echo "  remove - Remove MinIO"
    exit 1
    ;;
esac