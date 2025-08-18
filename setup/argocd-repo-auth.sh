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
  echo "║       ArgoCD Repository Authentication Setup          ║"
  echo "║         Add apollo-iac private repository             ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

check_prerequisites() {
  log_info "Checking prerequisites..."
  
  if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GITHUB_TOKEN environment variable not set"
    echo ""
    echo "Please set your GitHub Personal Access Token:"
    echo "1. Go to GitHub Settings > Developer settings > Personal access tokens"
    echo "2. Create a new token with 'repo' permissions"
    echo ""
    echo "Then run:"
    echo "export GITHUB_TOKEN=your_token_here"
    echo "$0"
    exit 1
  fi
  
  if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

add_repository_secret() {
  log_info "Adding apollo-iac repository authentication to ArgoCD..."
  
  # Create the repository secret
  kubectl create secret generic apollo-iac-repo \
    --namespace=argocd \
    --from-literal=type=git \
    --from-literal=url=https://github.com/matthewmyrick/apollo-iac \
    --from-literal=username=matthewmyrick \
    --from-literal=password="$GITHUB_TOKEN" \
    --from-literal=project=integrations \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Label the secret so ArgoCD recognizes it
  kubectl label secret apollo-iac-repo \
    --namespace=argocd \
    argocd.argoproj.io/secret-type=repository \
    --overwrite
  
  log_success "Repository authentication added"
}

verify_repository() {
  log_info "Verifying repository access..."
  
  # Wait a moment for ArgoCD to pick up the change
  sleep 5
  
  # Check if ArgoCD can access the repository
  if kubectl get secret apollo-iac-repo -n argocd &> /dev/null; then
    log_success "Repository secret created successfully"
  else
    log_error "Failed to create repository secret"
    exit 1
  fi
  
  log_info "ArgoCD should now be able to access the apollo-iac repository"
  log_info "You may need to refresh the ArgoCD application or wait a few minutes"
}

show_next_steps() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      Repository Authentication Complete! 🔐${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}Next steps:${NC}"
  echo "1. Check ArgoCD UI: http://home.apollo.io:30969"
  echo "2. Navigate to Settings > Repositories"
  echo "3. Verify apollo-iac repo shows as 'Successful'"
  echo "4. Try syncing your GitHub runners application"
  echo ""
  echo -e "${BLUE}If still having issues:${NC}"
  echo "kubectl logs -n argocd deployment/argocd-repo-server"
  echo "kubectl get applications -n argocd github-actions-runners -o yaml"
}

# Main execution
print_banner
check_prerequisites
add_repository_secret
verify_repository
show_next_steps